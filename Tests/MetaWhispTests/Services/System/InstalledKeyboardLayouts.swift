@testable import MetaWhisp

extension KeyboardLayoutMapper {
    // Real macOS layout data, independent of the user's enabled input sources.
    // Production keeps its enabled-only default. No system preferences mutate.
    static let installedForTests = KeyboardLayoutMapper(includeDisabledLayouts: true)
}
