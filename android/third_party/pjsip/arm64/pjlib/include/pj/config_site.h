/* === No video at all === */
#define PJMEDIA_HAS_VIDEO                 0
#define PJSUA_HAS_VIDEO                   0

/* === Keep only basic audio codecs === */
#define PJMEDIA_HAS_G711_CODEC            1
#define PJMEDIA_HAS_L16_CODEC             1

#define PJMEDIA_HAS_GSM_CODEC             0
#define PJMEDIA_HAS_G722_CODEC            0
#define PJMEDIA_HAS_G7221_CODEC           0
#define PJMEDIA_HAS_ILBC_CODEC            0
#define PJMEDIA_HAS_SPEEX_CODEC           0
#define PJMEDIA_HAS_OPUS_CODEC            0

/* === Disable echo cancellers you don't want to link === */
#define PJMEDIA_HAS_SPEEX_AEC             0
#define PJMEDIA_HAS_WEBRTC_AEC            0
#define PJMEDIA_HAS_WEBRTC_AEC3           0

/* === Disable Android MediaCodec audio backend === */
#define PJMEDIA_HAS_ANDROID_MEDIACODEC    0

/* === Disable external resamplers so nothing from libresample/speex is needed === */
#define PJMEDIA_RESAMPLE_USE_LIBRESAMPLE  0
#define PJMEDIA_RESAMPLE_USE_SPEEX        0
#define PJMEDIA_RESAMPLE_USE_LIBSAMPLERATE 0
/* (pjmedia will fall back to its simple internal path) */

/* Optional: avoid libyuv if you ever toggle video back on by mistake */
#define PJMEDIA_HAS_LIBYUV                0

