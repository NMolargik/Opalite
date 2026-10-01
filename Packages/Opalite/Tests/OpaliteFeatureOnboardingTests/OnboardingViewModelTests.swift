import Testing
import OpaliteCore
@testable import OpaliteFeatureOnboarding

@Suite("OnboardingViewModel paging")
struct OnboardingViewModelPagingTests {
    @Test func startsOnWelcome() {
        let model = OnboardingViewModel()
        #expect(model.step == .welcome)
        #expect(model.pageNumber == 1)
        #expect(model.pageCount == OnboardingStep.allCases.count)
        #expect(model.canGoBack == false)
        #expect(model.isLastStep == false)
        #expect(model.isFinished == false)
    }

    @Test func nextWalksEveryStepInOrder() {
        let model = OnboardingViewModel()
        var visited: [OnboardingStep] = [model.step]
        while !model.isLastStep {
            model.next()
            visited.append(model.step)
        }
        #expect(visited == OnboardingStep.allCases)
        #expect(model.direction == .forward)
        #expect(model.isFinished == false)
    }

    @Test func previousGoesBackAndStopsAtFirst() {
        let model = OnboardingViewModel(step: .canvas)
        model.previous()
        #expect(model.step == .portfolio)
        #expect(model.direction == .backward)
        model.previous()
        #expect(model.step == .welcome)
        model.previous()
        #expect(model.step == .welcome)
    }

    @Test func progressGrowsToOne() {
        let model = OnboardingViewModel()
        var last = 0.0
        var seen: [Double] = []
        repeat {
            #expect(model.progress > last)
            last = model.progress
            seen.append(last)
            if model.isLastStep { break }
            model.next()
        } while true
        #expect(seen.count == OnboardingStep.allCases.count)
        #expect(seen.last == 1.0)
    }

    @Test func continueTitleChangesOnLastPage() {
        let model = OnboardingViewModel()
        #expect(model.continueTitle == "Continue")
        let last = OnboardingViewModel(step: OnboardingStep.allCases.last!)
        #expect(last.continueTitle == "Done")
    }

    @Test func pageAnnouncementNamesThePage() {
        let model = OnboardingViewModel(step: .community)
        #expect(model.pageAnnouncement == "Page 4 of 5: Join the Community")
    }
}

@Suite("OnboardingViewModel finishing")
struct OnboardingViewModelFinishTests {
    @Test func nextOnLastPageFinishesOnce() {
        var finished: [String] = []
        let model = OnboardingViewModel(step: .profile, displayName: "Nick", onFinished: { finished.append($0) })
        model.next()
        model.next()
        #expect(model.isFinished)
        #expect(model.step == .profile)
        #expect(finished == ["Nick"])
    }

    @Test func skipFinishesFromAnyPage() {
        for step in OnboardingStep.allCases {
            var count = 0
            let model = OnboardingViewModel(step: step, onFinished: { _ in count += 1 })
            model.skip()
            #expect(model.isFinished)
            #expect(count == 1)
        }
    }

    @Test func finishIsIdempotent() {
        var count = 0
        let model = OnboardingViewModel(onFinished: { _ in count += 1 })
        model.finish()
        model.skip()
        model.next()
        #expect(count == 1)
    }

    @Test func finishPassesTrimmedName() {
        var received: String?
        let model = OnboardingViewModel(displayName: "  Nick Molargik \n", onFinished: { received = $0 })
        model.finish()
        #expect(received == "Nick Molargik")
    }
}

@Suite("Display name trimming")
struct DisplayNameTrimmingTests {
    @Test func trimsWhitespaceAndNewlines() {
        #expect(OnboardingViewModel.trimmed("  Ada \n") == "Ada")
        #expect(OnboardingViewModel.trimmed("\t\n  ") == "")
        #expect(OnboardingViewModel.trimmed("Ada Lovelace") == "Ada Lovelace")
    }

    @Test func trimmedDisplayNameFollowsDraft() {
        let model = OnboardingViewModel()
        model.displayName = "   "
        #expect(model.trimmedDisplayName.isEmpty)
        model.displayName = " Grace "
        #expect(model.trimmedDisplayName == "Grace")
    }

    @Test func anonymousDefaultPrefillsEmpty() {
        #expect(OnboardingViewModel.initialDisplayName(from: Authorship.anonymous.displayName) == "")
        #expect(OnboardingViewModel.initialDisplayName(from: " \(Authorship.anonymous.displayName) ") == "")
        #expect(OnboardingViewModel.initialDisplayName(from: "") == "")
        #expect(OnboardingViewModel.initialDisplayName(from: " Grace ") == "Grace")
    }
}

@Suite("Onboarding content")
struct OnboardingContentTests {
    @Test func everyStepHasAPage() {
        #expect(OnboardingPage.all.map(\.step) == OnboardingStep.allCases)
    }

    @Test func featurePagesHaveThreeRowsAndProfileIsAForm() {
        for page in OnboardingPage.all {
            if page.isForm {
                #expect(page.step == .profile)
                #expect(page.features.isEmpty)
            } else {
                #expect(page.features.count == 3)
                #expect(Set(page.features.map(\.id)).count == 3)
            }
            #expect(!page.title.isEmpty)
            #expect(!page.subtitle.isEmpty)
            #expect(!page.systemImage.isEmpty)
        }
    }
}
