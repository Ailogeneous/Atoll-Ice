//
//  ReminderLiveActivityManager.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 2025-11-12.
//

import Combine
import Defaults
import EventKit
import Foundation

@MainActor
final class ReminderLiveActivityManager: ObservableObject {
    struct ReminderEntry: Equatable {
        let event: EventModel
        let triggerDate: Date
        let leadTime: TimeInterval
    }

    static let shared = ReminderLiveActivityManager()

    @Published private(set) var activeReminder: ReminderEntry?
    @Published private(set) var currentDate: Date = Date()

    private var nextReminder: ReminderEntry?
    private var cancellables = Set<AnyCancellable>()
    private var tickerCancellable: AnyCancellable?
    private var evaluationTask: Task<Void, Never>?
    private var fallbackRefreshTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    private let calendarService: CalendarServiceProviding
    private let calendarManager = CalendarManager.shared

    var isActive: Bool { activeReminder != nil }

    private init(calendarService: CalendarServiceProviding = CalendarService()) {
        self.calendarService = calendarService
        setupObservers()
        Task { await self.refreshUpcomingReminder() }
    }

    private func setupObservers() {
        Defaults.publisher(.enableReminderLiveActivity, options: [])
            .sink { [weak self] change in
                guard let self else { return }
                if change.newValue {
                    self.scheduleRefresh(force: true)
                } else {
                    self.deactivateReminder()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(.reminderLeadTime, options: [])
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRefresh(force: true)
            }
            .store(in: &cancellables)

        Defaults.publisher(.reminderPresentationStyle, options: [])
            .sink { [weak self] _ in
                guard let self else { return }
                // Presentation change does not alter scheduling, but ensure state publishes for UI updates.
                if let reminder = self.activeReminder {
                    self.activeReminder = reminder
                }
            }
            .store(in: &cancellables)

        calendarManager.$allCalendars
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRefresh(force: true)
            }
            .store(in: &cancellables)

        calendarManager.$events
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRefresh(force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRefresh(force: true)
            }
            .store(in: &cancellables)
    }

    private func cancelAllTimers() {
        tickerCancellable?.cancel()
        tickerCancellable = nil
        evaluationTask?.cancel()
        evaluationTask = nil
        fallbackRefreshTask?.cancel()
        fallbackRefreshTask = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func deactivateReminder() {
        nextReminder = nil
        activeReminder = nil
        cancelAllTimers()
    }

    private func selectedCalendarIDs() -> [String] {
        calendarManager.allCalendars
            .filter { calendarManager.getCalendarSelected($0) }
            .map { $0.id }
    }

    private func shouldHide(_ event: EventModel) -> Bool {
        if event.isAllDay && Defaults[.hideAllDayEvents] {
            return true
        }
        if case let .reminder(completed) = event.type,
           completed && Defaults[.hideCompletedReminders] {
            return true
        }
        return false
    }

    private func makeEntry(from event: EventModel, leadMinutes: Int, referenceDate: Date) -> ReminderEntry? {
        guard event.start > referenceDate else { return nil }
        let leadSeconds = max(1, leadMinutes) * 60
        let trigger = event.start.addingTimeInterval(TimeInterval(-leadSeconds))
        return ReminderEntry(event: event, triggerDate: trigger, leadTime: TimeInterval(leadSeconds))
    }

    private func scheduleEvaluation(at date: Date) {
        evaluationTask?.cancel()
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else {
            Task { await self.evaluateCurrentState(at: Date()) }
            return
        }

        evaluationTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self.evaluateCurrentState(at: Date())
        }
    }

    private func scheduleFallbackRefresh() {
        fallbackRefreshTask?.cancel()
        let delay: TimeInterval = 15 * 60
        fallbackRefreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self.refreshUpcomingReminder()
        }
    }

    private func scheduleRefresh(force: Bool) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshUpcomingReminder(force: force)
        }
    }

    private func startTickerIfNeeded() {
        guard tickerCancellable == nil else { return }
        tickerCancellable = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.currentDate = date
                Task { await self.evaluateCurrentState(at: date) }
            }
    }

    private func stopTicker() {
        tickerCancellable?.cancel()
        tickerCancellable = nil
    }

    private func handleEntrySelection(_ entry: ReminderEntry?, referenceDate: Date) {
        fallbackRefreshTask?.cancel()
        nextReminder = entry
        Task { await self.evaluateCurrentState(at: referenceDate) }
    }

    private func refreshFromEvents(_ events: [EventModel], referenceDate: Date) {
        let leadMinutes = Defaults[.reminderLeadTime]
        let upcoming = events
            .filter { !shouldHide($0) }
            .compactMap { makeEntry(from: $0, leadMinutes: leadMinutes, referenceDate: referenceDate) }
            .sorted { $0.triggerDate < $1.triggerDate }

        guard let first = upcoming.first else {
            deactivateReminder()
            scheduleFallbackRefresh()
            return
        }

        handleEntrySelection(first, referenceDate: referenceDate)
    }

    func refreshUpcomingReminder(force: Bool = false) async {
        guard Defaults[.enableReminderLiveActivity] else {
            deactivateReminder()
            return
        }

        let now = Date()

        if !force, let entry = nextReminder, entry.event.start > now {
            await evaluateCurrentState(at: now)
            return
        }

        let calendars = selectedCalendarIDs()
        guard !calendars.isEmpty else {
            deactivateReminder()
            return
        }

        let windowEnd = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(24 * 60 * 60)
        let events = await calendarService.events(from: now, to: windowEnd, calendars: calendars)
        await MainActor.run {
            self.refreshFromEvents(events, referenceDate: now)
        }
    }

    func evaluateCurrentState(at date: Date) async {
        guard Defaults[.enableReminderLiveActivity] else {
            deactivateReminder()
            return
        }

        currentDate = date

        guard var entry = nextReminder else {
            activeReminder = nil
            stopTicker()
            return
        }

        if entry.event.start <= date {
            activeReminder = nil
            nextReminder = nil
            stopTicker()
            scheduleRefresh(force: true)
            return
        }

        if entry.triggerDate <= date {
            if entry.triggerDate > entry.event.start {
                entry = ReminderEntry(event: entry.event, triggerDate: entry.event.start, leadTime: entry.leadTime)
                nextReminder = entry
            }
            if activeReminder != entry {
                activeReminder = entry
            }
            startTickerIfNeeded()
        } else {
            if activeReminder != nil {
                activeReminder = nil
            }
            stopTicker()
            scheduleEvaluation(at: entry.triggerDate)
        }
    }
}
