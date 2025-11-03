// pjsip_shim.cpp — JNI shim + link-wraps + TX sanitizer module
#define SHIM_BUILD_TAG "shim-wrap-uniq-v4.1-sanitize"

#include <pj/types.h>
#include <pj/pool.h>
#include <pj/string.h>
#include <pj/os.h>
#include <pjlib.h>

#include <pjsua2.hpp>
#include <pjsua-lib/pjsua.h>
#include <pjsip.h>

#include <android/log.h>
#include <string>
#include <string.h>
#include <memory>
#include <stdint.h>
#include <atomic>

using namespace pj;
using namespace std;

#if defined(__GNUC__) || defined(__clang__)
#define JNI_EXPORT extern "C" __attribute__((visibility("default")))
#else
#define JNI_EXPORT extern "C"
#endif

class AndroidLogWriter : public LogWriter {
public:
    void write(const LogEntry &e) override {
        __android_log_print(ANDROID_LOG_INFO, "PJSIP", "%s", e.msg.c_str());
    }
};

static Endpoint ep;
static bool g_libReady = false;
static bool g_started  = false;
static AndroidLogWriter g_logWriter;
static TransportId g_udp_tid = PJSUA_INVALID_ID;

struct MyAccount : public Account {
    void onRegState(OnRegStateParam &prm) override {
        AccountInfo ai = getInfo();

        __android_log_print(ANDROID_LOG_INFO, "PJSIP",
                            "🌸 onRegState fired: code=%d reason=%s active=%d uri=%s",
                            prm.code, prm.reason.c_str(), (int)ai.regIsActive, ai.uri.c_str());

        // 🚫 Authentication failed
        if (prm.code == 401 || prm.code == 403) {
            __android_log_print(ANDROID_LOG_WARN, "PJSIP",
                                "⚠️ Auth failed (code=%d), stopping registration", prm.code);
            try {
                setRegistration(false);
                pjsua_acc_set_registration(getId(), PJ_FALSE);
                __android_log_print(ANDROID_LOG_INFO, "PJSIP", "💤 Registration stopped");
            } catch (...) {
                __android_log_print(ANDROID_LOG_ERROR, "PJSIP", "Error stopping registration");
            }
        }

        // ✅ Successful registration
        if (ai.regIsActive && prm.code == 200) {
            __android_log_print(ANDROID_LOG_INFO, "PJSIP",
                                "🎉 Registered successfully: %s", ai.uri.c_str());
        }

        // 💤 Inactive cleanup
        if (!ai.regIsActive && prm.code >= 400) {
            __android_log_print(ANDROID_LOG_INFO, "PJSIP",
                                "🧹 Registration inactive, cleaning up.");
            try { pjsua_acc_set_online_status(getId(), PJ_FALSE); } catch (...) {}
        }
    }

};

static std::unique_ptr<MyAccount> acc;
static AccountConfig g_acfg;

// =========================== Utilities ===========================
static inline void fill_hex_32(char out[33], const void* salt_ptr=nullptr) {
    pj_time_val tv; pj_gettimeofday(&tv);
    static std::atomic<uint32_t> ctr{0};
    uintptr_t salt = (uintptr_t)(salt_ptr ? salt_ptr : out);
    uint64_t t = ((uint64_t)tv.sec << 32) | (uint64_t)tv.msec;
    uint64_t mix = t ^ (uint64_t)salt ^ (uint64_t(++ctr) * 0x9E3779B97f4A7C15ULL);
    for (int i=0;i<32;++i) { mix ^= mix<<13; mix^=mix>>7; mix^=mix<<17;
        uint8_t v=(uint8_t)(mix & 0x0F);
        out[i] = (v<10)?('0'+v):('a'+(v-10));
    }
    out[32]='\0';
}

static inline bool pj_str_has_only_printables(const pj_str_t *s) {
    if (!s || !s->ptr) return false;
    for (int i=0;i<s->slen;i++) { unsigned char c=(unsigned char)s->ptr[i];
        if (c<33 || c>126) return false;
    }
    return s->slen>0;
}

// ========================= Link WRAPs ============================
extern "C" pj_str_t* __wrap_pj_generate_unique_string(pj_str_t *str) {
    thread_local char buf[33]; fill_hex_32(buf); pj_strset(str, buf, 32); return str;
}
extern "C" void __wrap_pj_create_unique_string(pj_pool_t *pool, pj_str_t *str) {
    char tmp[33]; fill_hex_32(tmp); pj_strdup2_with_null(pool, str, tmp);
}
extern "C" pj_str_t* __wrap_pj_generate_unique_string2(pj_str_t *str) {
    thread_local char buf[33]; fill_hex_32(buf); pj_strset(str, buf, 32); return str;
}
extern "C" void __wrap_pj_create_unique_string2(pj_pool_t *pool, pj_str_t *str) {
    char tmp[33]; fill_hex_32(tmp); pj_strdup2_with_null(pool, str, tmp);
}
extern "C" void __wrap_pj_create_random_string(pj_str_t *str, unsigned length) {
    unsigned L=(length>32u)?32u:length; thread_local char buf[33]; fill_hex_32(buf); pj_strset(str, buf, L);
}
extern "C" void __wrap_pj_guid_create(void *guid_like) {
    unsigned char *p = reinterpret_cast<unsigned char*>(guid_like);
    pj_time_val tv; pj_gettimeofday(&tv); static std::atomic<uint32_t> ctr{0};
    uint64_t t=((uint64_t)tv.sec<<32)|(uint64_t)tv.msec;
    uint64_t mix=t ^ (uint64_t)(uintptr_t)p ^ (uint64_t(++ctr)*0x9E3779B97f4A7C15ULL);
    for (int i=0;i<16;++i){ mix^=mix<<13; mix^=mix>>7; mix^=mix<<17; p[i]=(unsigned char)(mix & 0xFF); }
}

// ===================== TX sanitizer module ======================
static pj_status_t shim_on_tx_request(pjsip_tx_data *tdata) {
    if (!tdata || !tdata->msg || !tdata->pool) return PJ_SUCCESS;

    if (auto *cid=(pjsip_cid_hdr*)pjsip_msg_find_hdr(tdata->msg, PJSIP_H_CALL_ID, NULL)) {
        if (!pj_str_has_only_printables(&cid->id) || cid->id.slen==0) {
            char idbuf[33]; fill_hex_32(idbuf, tdata);
            pj_strdup2_with_null(tdata->pool, &cid->id, idbuf);
            __android_log_print(ANDROID_LOG_INFO,"PJSIP","shim: fixed Call-ID -> %.*s",(int)cid->id.slen,cid->id.ptr);
        }
    }
    if (auto *via=(pjsip_via_hdr*)pjsip_msg_find_hdr(tdata->msg, PJSIP_H_VIA, NULL)) {
        if (!pj_str_has_only_printables(&via->branch_param) || via->branch_param.slen==0) {
            char hex[33]; fill_hex_32(hex, tdata);
            char branch_buf[8+32+1]; memcpy(branch_buf,"z9hG4bK",7); branch_buf[7]='\0';
            strncat(branch_buf, hex, 32);
            pj_strdup2_with_null(tdata->pool, &via->branch_param, branch_buf);
            __android_log_print(ANDROID_LOG_INFO,"PJSIP","shim: fixed Via branch -> %.*s",(int)via->branch_param.slen,via->branch_param.ptr);
        }
    }
    return PJ_SUCCESS;
}
static pj_status_t shim_on_tx_response(pjsip_tx_data *tdata){ PJ_UNUSED_ARG(tdata); return PJ_SUCCESS; }

static pjsip_module shim_mod;
static void register_shim_module_once() {
    static bool installed=false; if (installed) return;
    pj_bzero(&shim_mod, sizeof(shim_mod));
    shim_mod.name = pj_str((char*)"mod-shim-sanitize");
    shim_mod.id = -1;
    shim_mod.priority = PJSIP_MOD_PRIORITY_TSX_LAYER + 1;
    shim_mod.on_tx_request  = &shim_on_tx_request;
    shim_mod.on_tx_response = &shim_on_tx_response;

    if (auto *endpt=pjsua_get_pjsip_endpt()) {
        pj_status_t st=pjsip_endpt_register_module(endpt,&shim_mod);
        if (st==PJ_SUCCESS){ installed=true; __android_log_print(ANDROID_LOG_INFO,"PJSIP","shim: sanitize module registered"); }
        else { __android_log_print(ANDROID_LOG_ERROR,"PJSIP","shim: module register failed: %d",(int)st); }
    }
}

// =========================== Helpers ============================
static pjsip_transport_type_e to_tt(int t) {
    return (t==2)?PJSIP_TRANSPORT_TLS : (t==1)?PJSIP_TRANSPORT_TCP : PJSIP_TRANSPORT_UDP;
}

// ============================ API ===============================
JNI_EXPORT int pjsip2_init(int logLevel){
    try{
        if (g_libReady) return 0;
        ep.libCreate();
        EpConfig epc;
        epc.logConfig.level=logLevel;
        epc.logConfig.consoleLevel=logLevel;
        epc.logConfig.writer=&g_logWriter;
        epc.uaConfig.userAgent="WavenetSoftphone/1.0";
        epc.uaConfig.maxCalls=4;
        ep.libInit(epc);
        g_libReady=true;
        register_shim_module_once();
        __android_log_print(ANDROID_LOG_INFO,"PJSIP","Shim build: %s",SHIM_BUILD_TAG);
        __android_log_print(ANDROID_LOG_INFO,"PJSIP","libInit OK");
        return 0;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","libInit fail: %s", e.info().c_str());
        return -1;
    }
}

JNI_EXPORT int pjsip2_transport(int transport,const char* bindAddr,int port){
    try{
        TransportConfig tcfg;
        if (bindAddr && bindAddr[0]) {
            tcfg.boundAddress  = std::string(bindAddr);
            tcfg.publicAddress = std::string(bindAddr);
        }
        tcfg.port=port; // 0 = auto

        TransportId tid = ep.transportCreate(to_tt(transport), tcfg);
        if (transport==0) g_udp_tid = tid; // remember UDP id

        TransportInfo ti = ep.transportGetInfo(tid);
        __android_log_print(ANDROID_LOG_INFO,"PJSIP",
                            "transport created: type=%s tid=%d localName=%s public=%s",
                            ti.typeName.c_str(), (int)tid, ti.localName.c_str(),
                            tcfg.publicAddress.empty()?"(none)":tcfg.publicAddress.c_str());
        return (int)tid;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","transport fail: %s", e.info().c_str());
        return -2;
    }
}

JNI_EXPORT int pjsip2_start(){
    try{
        if (!g_libReady) return -3;
        if (g_started) { __android_log_print(ANDROID_LOG_INFO,"PJSIP","libStart skipped"); return 0; }
        ep.libStart(); g_started=true;
        __android_log_print(ANDROID_LOG_INFO,"PJSIP","libStart OK");
        return 0;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","libStart fail: %s", e.info().c_str());
        return -3;
    }
}

// 2-phase (kept for completeness)
JNI_EXPORT int pjsip2_add_account(const char* idUri,const char* regUri){
    try{
        if (!g_libReady) return -1;
        g_acfg = AccountConfig{};
        g_acfg.idUri = idUri? idUri : "";

        std::string reg = regUri? regUri : "";
        if (!reg.empty() && reg.rfind("sip:",0)!=0) reg = "sip:"+reg;
        g_acfg.regConfig.registrarUri=reg;

        g_acfg.regConfig.registerOnAdd = false;
        g_acfg.natConfig.udpKaIntervalSec=25;
        g_acfg.natConfig.sipOutboundUse=0;  // no ;ob
        g_acfg.natConfig.contactRewriteUse=1;
        g_acfg.natConfig.viaRewriteUse=1;
        if (g_udp_tid!=PJSUA_INVALID_ID) g_acfg.sipConfig.transportId=g_udp_tid;

        g_acfg.sipConfig.authCreds.clear();

        acc = std::make_unique<MyAccount>();
        acc->create(g_acfg);
//        acc->setRegistration(true); // unauth REGISTER

        __android_log_print(ANDROID_LOG_INFO,"PJSIP","add_account: unauth REGISTER sent: %s", g_acfg.idUri.c_str());
        return 0;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","add_account fail: %s", e.info().c_str());
        return -2;
    }
}

JNI_EXPORT int pjsip2_set_credentials(const char* authUser,const char* password,const char* realm){
    try{
        if (!acc) return -1;
        std::string usr = authUser? authUser : "";
        std::string pwd = password? password : "";
        std::string rlm = (realm && realm[0])? realm : "*";

        g_acfg.sipConfig.authCreds.clear();
        g_acfg.sipConfig.authCreds.push_back(AuthCredInfo("digest", rlm, usr, 0, pwd));
        acc->modify(g_acfg);
//        acc->setRegistration(true); // auth REGISTER
        __android_log_print(ANDROID_LOG_INFO,"PJSIP","set_credentials: user=%s realm=%s (re-REGISTER)", usr.c_str(), rlm.c_str());
        return 0;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","set_credentials fail: %s", e.info().c_str());
        return -2;
    }
}

JNI_EXPORT int pjsip2_reregister(){
    try{ if (!acc) return -1; acc->setRegistration(true); return 0; }
    catch(const Error &e){ __android_log_print(ANDROID_LOG_ERROR,"PJSIP","reregister fail: %s", e.info().c_str()); return -2; }
}

// One-shot: creds preinstalled, registerOnAdd = true, no ;ob
JNI_EXPORT int pjsip2_register_with_credentials(
        const char* idUri,
        const char* regUri,
        const char* authUser,
        const char* password,
        const char* realm)
{
    try {
        if (!g_libReady)
            return -10;

        // 🧹 Clean up old account if any
        if (acc) {
            acc->shutdown();
            acc.reset();
        }

        std::string id  = idUri ? idUri : "";
        std::string reg = regUri ? regUri : "";
        std::string usr = authUser ? authUser : "";
        std::string pwd = password ? password : "";
        std::string rlm = (realm && realm[0]) ? realm : "asterisk";

        // 💡 Ensure SIP prefix
        if (id.rfind("sip:", 0) != 0)
            id = "sip:" + id;
        if (reg.rfind("sip:", 0) != 0)
            reg = "sip:" + reg;

        // 🧠 Debug print
        __android_log_print(ANDROID_LOG_INFO, "PJSIP",
                            "🔧 Account Config:\n"
                            "  ID=%s\n  REG=%s\n  USER=%s\n  REALM=%s",
                            id.c_str(), reg.c_str(), usr.c_str(), rlm.c_str());

        // 🧩 Setup account
        AccountConfig acfg;
        acfg.idUri = id;
        acfg.regConfig.registrarUri = reg;
        acfg.regConfig.registerOnAdd = false; // manually trigger
        acfg.regConfig.retryIntervalSec = 0;
        acfg.regConfig.firstRetryIntervalSec = 0;
        acfg.natConfig.contactRewriteUse = 1;
        acfg.natConfig.viaRewriteUse = 1;
        acfg.natConfig.udpKaIntervalSec = 25;

        // 🔐 Credentials
        acfg.sipConfig.authCreds.clear();
        acfg.sipConfig.authCreds.push_back(AuthCredInfo("digest", rlm, usr, 0, pwd));
        acfg.sipConfig.authCreds.push_back(AuthCredInfo("digest", "*", usr, 0, pwd));

        if (g_udp_tid != PJSUA_INVALID_ID)
            acfg.sipConfig.transportId = g_udp_tid;

        // 🚀 Create and register
        acc = std::make_unique<MyAccount>();
        acc->create(acfg);
        acc->setRegistration(true);  // ✅ Fire REGISTER manually

        __android_log_print(ANDROID_LOG_INFO, "PJSIP",
                            "✅ Registration initiated for %s (realm=%s, user=%s)",
                            id.c_str(), rlm.c_str(), usr.c_str());

        return 0;
    } catch (const Error &e) {
        __android_log_print(ANDROID_LOG_ERROR, "PJSIP",
                            "❌ reg_with_creds fail: %s", e.info().c_str());
        return -11;
    }
}







JNI_EXPORT int pjsip2_login(const char* idUri,const char* regUri,
                            const char* authUser,const char* password,
                            const char* realm){
    try{
        if (!g_libReady) return -5;
        if (acc) { acc->shutdown(); acc.reset(); }

        const std::string id  = idUri? idUri : "";
        const std::string reg = regUri? regUri : "";
        const std::string usr = authUser? authUser : "";
        const std::string pwd = password? password : "";
        const std::string rlm = (realm && realm[0])? realm : "*";

        AccountConfig acfg; acfg.idUri=id;
        if (!reg.empty() && reg.rfind("sip:",0)!=0) acfg.regConfig.registrarUri="sip:"+reg;
        else acfg.regConfig.registrarUri=reg;

        acfg.regConfig.registerOnAdd=true;
        if (g_udp_tid!=PJSUA_INVALID_ID) acfg.sipConfig.transportId=g_udp_tid;

        acfg.sipConfig.authCreds.clear();
        acfg.sipConfig.authCreds.clear();
        acfg.sipConfig.authCreds.push_back(AuthCredInfo("digest", rlm, usr, 0, pwd));  // specific realm (e.g. "asterisk")
        acfg.sipConfig.authCreds.push_back(AuthCredInfo("digest", "*",  usr, 0, pwd));

        acfg.natConfig.udpKaIntervalSec=25;
        acfg.natConfig.sipOutboundUse=0; // no ;ob
        acfg.natConfig.contactRewriteUse=1;
        acfg.natConfig.viaRewriteUse=1;

        acc = std::make_unique<MyAccount>();
        acc->create(acfg);
        acc->setRegistration(true);
        __android_log_print(ANDROID_LOG_INFO,"PJSIP","Account REGISTER sent: %s", id.c_str());
        return 0;
    } catch(const Error &e){
        __android_log_print(ANDROID_LOG_ERROR,"PJSIP","login fail: %s", e.info().c_str());
        return -6;
    } catch(...){
        return -7;
    }
}

JNI_EXPORT void pjsip2_shutdown() {
    try {
        if (acc) {
            acc->shutdown();
            acc.reset();
        }

        if (g_libReady) {
            try {
                ep.hangupAllCalls(); // just in case
            } catch (...) {}

            pj_thread_sleep(100); // give worker threads a tick

            ep.libDestroy(false); // ⚠️ pass false → skip pool freeing (avoids double free)
            g_libReady = false;
            g_started  = false;
        }

        __android_log_print(ANDROID_LOG_INFO, "PJSIP", "shutdown complete (safe mode)");
    } catch (...) {
        __android_log_print(ANDROID_LOG_ERROR, "PJSIP", "shutdown exception");
    }
}

