const String kGlobalDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';
Map<String, String> kGlobalDefaultHeaders = {
  'user-agent': kGlobalDefaultUserAgent,
};
const Map<String, String> kBilibiliPlayHeader = {
  "user-agent":
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36",
  "accept": "*/*",
  "accept-encoding": "identity;q=1, *;q=0",
  "accept-language": "zh-CN",
  "referer": "https://www.bilibili.com/",
  "sec-fetch-dest": "audio",
  "sec-fetch-mode": "no-cors",
  "sec-fetch-site": "cross-site",
  "range": "bytes=0-",
};
