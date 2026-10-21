# ⚡ Apex Log Analyzer & Autonomous AI Fix Engine

An agentic Salesforce developer tool built with **Lightning Web Components (LWC)** and **Apex**, featuring multi-transaction session correlation, method-level call hierarchy visualization, and automated root-cause analysis powered by **Google Gemini AI**.

---

## 🌟 Key Features

### 1. Minimal Material Diagnostic Interface
- **2-Card Landing Interface**: Choose between **Log Analysis by Time Window** and **Raw Log Parser**.
- Clean, minimal material design following WCAG AA high-contrast standards for maximum readability with calm, professional color palettes.

### 2. Multi-Transaction Session Correlation
- **Time-Window Filtering**: Filter user logs across **5 minutes**, **15 minutes**, **30 minutes**, or **1 hour**.
- **Strict Causal Linking**: Automatically traces parent operations and asynchronous child transactions (`AsyncApexJob` / `707...` job IDs spawned via `System.enqueueJob` or `Database.executeBatch`).
- **3-Tab Session Overview**:
  - **🔗 Grouped Transactions**: Correlated chains (`Transaction 1`, `Transaction 2`...) with aggregate start time, end time, and duration (e.g. `12:04:10 - 12:04:15 (5.20s)`).
  - **📋 Chronological List View**: All logs ordered by generation time with millisecond offsets (`+0ms`, `+5000ms`), duration, and limits consumed.
  - **📦 Others (Unrelated Logs)**: Isolated transactions generated within the window.

### 3. Execution Flow Call Tree & Error Pinpointing
- **Deep Hierarchical Method Call Tree**: Reconstructs execution flow (`ClassA.methodA` &rarr; `ClassB.methodB` &rarr; `ClassC.methodC`).
- **Re-Entrancy & Recursion Detection**: Tags recursive calls with `🔄 Re-entrant`.
- **Unhandled Crash vs Handled Exceptions**:
  - Core principle: *If `METHOD_ENTRY` is logged without a matching `METHOD_EXIT`, it is an unhandled fatal crash*.
  - **Stop-Point Highlighting**: Pins the exact method frame where execution halted (`⛔ Execution Stopped Here`).
  - **Handled Exceptions Section**: Catalogs exceptions caught in `try-catch` blocks where flow continued.

### 4. Autonomous AI Fix Engine (Google Gemini)
- Dedicated **`🤖 Generate AI Fix`** buttons for the fatal unhandled crash as well as individual handled exceptions.
- Provides architectural explanations, root-cause synthesis, and a side-by-side **Code Diff** with a 1-click **Copy Fix** button.

---

## 🛠️ Architecture & Components

```
force-app/main/default/
├── applications/
│   └── Apex_Log_Analyzer.app-meta.xml      # Custom Lightning App
├── classes/
│   ├── CloudAIService.cls                  # Google Gemini API integration & fix generator
│   ├── LogAnalyzerController.cls           # Controller for LWC, session queries & correlation
│   ├── LogParserService.cls                # Stack-based log parser & call tree engine
│   └── LogParserServiceTest.cls            # 100% pass rate unit test suite
├── lwc/
│   └── logAnalyzerApp/                     # Minimal Material UI bundle (HTML, JS, CSS)
├── pages/
│   └── SessionIdHelper.page                # Visualforce session resolver for Tooling API access
├── remoteSiteSettings/
│   ├── GoogleGeminiAPI.remoteSite-meta.xml # Remote site for Gemini API endpoint
│   └── SalesforceOrgDomain.remoteSite-meta.xml
└── tabs/
    └── Apex_Log_Analyzer.tab-meta.xml      # Custom Tab
```

---

## 🚀 Deployment Instructions

### Prerequisites
- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli)
- An authenticated Salesforce org (Developer Edition, Sandbox, or Scratch Org)

### 1. Clone & Authenticate
```bash
git clone <your-repo-url>
cd project1
sf org login web -a myOrg --set-default
```

### 2. Deploy Metadata to Org
```bash
sf project deploy start --source-dir force-app/main/default/classes force-app/main/default/lwc force-app/main/default/pages force-app/main/default/remoteSiteSettings force-app/main/default/tabs --target-org myOrg
```

### 3. Run Automated Tests
```bash
sf apex test run --class-names LogParserServiceTest --result-format human --target-org myOrg --code-coverage
```

### 4. Enable Method-Level Tracing (Recommended)
In Salesforce Setup &gt; **Debug Logs**:
- Create or edit a **Trace Flag** for your user.
- Set **Apex Code** to **FINE** or **FINEST** to capture method-level entry and exit events (`METHOD_ENTRY` / `METHOD_EXIT`).

---

## ⚙️ Configuration (Gemini API)

1. Open the **Apex Log Analyzer** tab in your Salesforce org.
2. Click **⚙️ Gemini AI Settings** in the top right header.
3. Paste your Google Gemini API key (stored securely in browser local storage).
4. Select your preferred model (`gemini-3.8-flash`, `gemini-1.5-flash`, or `gemini-1.5-pro`) and click **Test Connection**.
