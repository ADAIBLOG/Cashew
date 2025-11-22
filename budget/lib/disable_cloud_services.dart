// 云服务禁用配置文件
// 通过导入此文件可以在不修改核心代码的情况下禁用Google登录和Firebase服务

// 设置为true以禁用所有云服务
// 由于不需要使用任何云服务，这里直接设置为true
const bool disableAllCloudServices = true;

// 修改默认设置以禁用云功能
void applyCloudServicesDisableSettings(Map<String, dynamic> settings) {
  if (disableAllCloudServices) {
    // 禁用Google登录相关功能
    settings["enableGoogleLoginFlyIn"] = false;
    settings["hasSignedIn"] = false;
    settings["lastLoginVersion"] = "";
    settings["numLogins"] = 0;
    settings["forceAutoLogin"] = false;
    
    // 禁用备份功能
    settings["autoBackups"] = false;
    settings["backupsEnabled"] = false;
    
    // 禁用同步功能
    settings["syncEveryChange"] = false;
    settings["webForceLoginPopupOnLaunch"] = false;
    
    // 禁用共享功能
    settings["sharedBudgets"] = false;
    
    // 禁用电子邮件相关功能
    settings["emailScanning"] = false;
    settings["EmailAutoTransactions-amountOfEmails"] = 0;
    settings["AutoTransactions-canReadEmails"] = false;
    
    // 清空用户信息
    settings["currentUserEmail"] = "";
    settings["username"] = "";

   
    // 禁用云交易功能
    settings["cloudTransactions"] = false;
    
    // 禁用汇率相关功能
    settings["cachedCurrencyExchange"] = {};
    settings["customCurrencies"] = [];
    settings["customCurrencyAmounts"] = {};
    
    // 完全禁用所有可能的网络功能
    settings["enableNetworkFeatures"] = false;
    settings["enableCloudSync"] = false;
    settings["enableRemoteData"] = false;
    settings["hasCheckedCloudStatus"] = true; // 避免启动时检查云状态
    settings["lastCloudSync"] = 0;
    settings["hasSyncedBefore"] = false;
    settings["cloudSyncEnabled"] = false;
  }
}

