const videoDownloadFailureReasons = {
  'downloadFailed',
  'network',
  'waitingNetwork',
  'waitingWifi',
  'httpForbidden',
  'httpNotFound',
  'loginRequired',
  'verificationRequired',
  'mediaRejected',
  'outOfSpace',
  'routeUnavailable',
  'sourceVisitRequired',
  'sourceRemoved',
  'accountChanged',
  'qualityUnavailable',
  'missingIdentity',
  'unsupported',
  'cancelled',
  'storage',
  'timeout',
  'httpError',
  'incomplete',
  'invalidRequest',
  'redirectRejected',
  'unavailable',
};
String videoDownloadFailureText(
  Object? reason, {
  required bool chinese,
  bool inWork = false,
}) => switch (reason) {
  'timeout' =>
    chinese ? '下载请求超时，可重试。' : 'The download request timed out. Retry.',
  'storage' =>
    chinese
        ? '文件未能保存，请检查设备存储后重试。'
        : 'The file could not be saved. Check device storage and retry.',
  'incomplete' =>
    chinese ? '视频文件未下载完整，可重试。' : 'The video file is incomplete. Retry.',
  'httpError' =>
    chinese
        ? '下载服务器暂未完成请求，可重试。'
        : 'The download server did not complete the request. Retry.',
  'redirectRejected' =>
    chinese
        ? '下载暂不可用，请重试。'
        : 'The download redirect is unavailable. Retry with a fresh address.',
  'network' =>
    chinese ? '网络请求未完成，请重试。' : 'The network request did not complete. Retry.',
  'waitingNetwork' => chinese ? '等待网络' : 'Waiting for network',
  'waitingWifi' => chinese ? '等待 Wi-Fi' : 'Waiting for Wi-Fi',
  'httpForbidden' =>
    chinese
        ? '下载被拒绝，请重试。'
        : 'The download server refused this request. Retry with a fresh address.',
  'httpNotFound' =>
    chinese
        ? '下载地址已失效，请重试。'
        : 'The download address is unavailable. Retry with a fresh address.',
  'loginRequired' =>
    chinese
        ? '请先在此来源登录，再重试下载。'
        : 'Sign in to this source, then retry the download.',
  'verificationRequired' =>
    chinese
        ? '请先在此来源完成验证，再重试下载。'
        : 'Complete verification in this source, then retry.',
  'mediaRejected' =>
    chinese
        ? '服务器未返回可下载的视频文件。'
        : 'The server did not return a downloadable video file.',
  'outOfSpace' =>
    chinese ? '设备空间不足，请腾出空间后重试。' : 'Free device storage, then retry.',
  'routeUnavailable' =>
    chinese
        ? '当前下载无法使用此来源的网络线路。'
        : 'This source’s current network route is unavailable for downloading.',
  'sourceVisitRequired' =>
    inWork
        ? chinese
              ? '暂时无法读取下载地址，请重试。'
              : 'The download address could not be read. Retry.'
        : chinese
        ? '请到作品中确认下载选项。'
        : 'Check the download options in the work.',
  'sourceRemoved' =>
    chinese
        ? '此来源已移除，暂时无法重新读取下载地址。'
        : 'This source was removed. Its download address cannot be refreshed.',
  'accountChanged' =>
    chinese
        ? '账号已切换，本次下载已停止。请重试。'
        : 'The account changed. This attempt stopped; you can retry.',
  'qualityUnavailable' =>
    inWork
        ? chinese
              ? '原下载选项已不可用，请重新选择。'
              : 'The original download option is unavailable. Choose again.'
        : chinese
        ? '原画质已不可用，请在作品中重新选择画质。'
        : 'The original quality is unavailable. Choose a quality in the work.',
  'missingIdentity' =>
    inWork
        ? chinese
              ? '请重新选择要下载的剧集。'
              : 'Select the episode to download again.'
        : chinese
        ? '请选择剧集和画质后重新下载。'
        : 'Choose an episode and quality to download again.',
  'unsupported' =>
    chinese
        ? '当前设备不支持下载此视频格式。'
        : 'Downloading this video format is unsupported on this device.',
  _ => chinese ? '下载未完成。' : 'The download did not complete.',
};
