/// Fires when this feature has toast copy to show — a purchase result, a
/// restore outcome, or a voucher redemption result. Purely a signal: the
/// screen turns it into a ``DesignSystem/ToastQueue`` item. Mirrors
/// `SharedFeatures`' `TuneInToastEvent`/`LikeFailureEvent` shape (id +
/// message, incrementing so two toasts in a row are still distinct values
/// for `onChange(of:)`), duplicated here rather than reused because
/// SharedFeatures never imports `SecretDJAPI` (ios-architecture) and this
/// feature is consumer-only.
struct TopUpToastEvent: Equatable {
	let id: Int
	let message: String
}
