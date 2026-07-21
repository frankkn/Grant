/// 後端服務（Cloud Run, asia-east1）的 base URL。
/// 需要驗證呼叫者身分的操作（推播、配對）都打這個服務，
/// 由後端以 Firebase Admin SDK 驗證 ID token 後執行。
const backendBaseUrl = 'https://grant-backend-1075079498116.asia-east1.run.app';
