import Testing
import Foundation
@testable import Mnemis

/// Порядок шагов онбординга: сначала вход (необязательный), затем настройки и темп (ABOUT.md, раздел 37).
@MainActor
struct OnboardingFlowTests {
    let clock = TestClock()

    @Test func welcomeLeadsToSignInFirst() throws {
        let model = OnboardingViewModel(container: try AppContainer.inMemory(clock: clock))
        model.step = .welcome

        model.next()

        #expect(model.step == .account)
    }

    @Test func signInOrSkipLeadsToLevelSetup() throws {
        let model = OnboardingViewModel(container: try AppContainer.inMemory(clock: clock))
        model.step = .account

        model.next()

        #expect(model.step == .level)
    }

    @Test func levelLeadsToPace() throws {
        let model = OnboardingViewModel(container: try AppContainer.inMemory(clock: clock))
        model.step = .level

        model.next()

        #expect(model.step == .pace)
    }

    @Test func paceLeadsToNotificationsWhenRemindersAreOn() throws {
        let model = OnboardingViewModel(container: try AppContainer.inMemory(clock: clock))
        model.step = .pace
        model.remindersOn = true

        model.next()

        #expect(model.step == .notifications)
    }

    @Test func paceFinishesOnboardingWhenRemindersAreOff() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let model = OnboardingViewModel(container: container)
        model.step = .pace
        model.remindersOn = false

        model.next()

        #expect(container.router.isOnboarded)
        #expect(try container.settings.load().onboardingCompleted)
    }

    @Test func backFromLevelReturnsToSignIn() throws {
        let model = OnboardingViewModel(container: try AppContainer.inMemory(clock: clock))
        model.step = .level

        model.back()

        #expect(model.step == .account)
    }
}
