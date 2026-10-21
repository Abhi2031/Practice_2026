import { LightningElement, track, wire } from 'lwc';
import getRecentLogs from '@salesforce/apex/LogAnalyzerController.getRecentLogs';
import analyzeRawLog from '@salesforce/apex/LogAnalyzerController.analyzeRawLog';
import analyzeLogById from '@salesforce/apex/LogAnalyzerController.analyzeLogById';
import analyzeUserRecentLogs from '@salesforce/apex/LogAnalyzerController.analyzeUserRecentLogs';
import requestAIFixWithConfig from '@salesforce/apex/LogAnalyzerController.requestAIFixWithConfig';
import testGeminiConnection from '@salesforce/apex/LogAnalyzerController.testGeminiConnection';

export default class LogAnalyzerApp extends LightningElement {
    @track recentLogs = [];
    @track selectedLogId = '';
    @track rawLogInput = '';

    // Flow Selection State (Landing -> Option UI)
    @track selectedAppFlow = null; // 'timeAnalysis' | 'rawParser' | null
    @track selectedWindowMinutes = 5; // 5, 15, 30, 60
    @track activeOverviewTab = 'grouped'; // 'grouped' | 'chronological' | 'unrelated'

    // Analysis Loading States
    @track isAnalyzingSingle = false;
    @track isAnalyzingMulti = false;
    @track isAnalyzingRaw = false;
    @track isGeneratingFix = false;
    @track isTestingConnection = false;

    // Results & State
    @track analysisResult = null;
    @track multiLogResult = null;
    @track isMultiLogMode = false;
    @track isDrilledDownToSingleLog = false;
    @track showTraceNotice = true;
    @track treeSearchQuery = '';
    @track collapsedNodeIds = new Set();
    @track aiFix = null;
    @track activeFixingErrorId = '';
    @track uiError = '';

    // Copy Button Feedback State
    @track isCopied = false;

    // Gemini Modal State
    @track showGeminiModal = false;
    @track geminiApiKey = '';
    @track geminiModel = 'gemini-3.8-flash';
    @track geminiTestStatus = '';
    @track isGeminiTestSuccess = false;
    @track showPassword = false;

    connectedCallback() {
        try {
            const savedKey = localStorage.getItem('apex_ai_gemini_key');
            if (savedKey) {
                this.geminiApiKey = savedKey;
            }
            const savedModel = localStorage.getItem('apex_ai_gemini_model');
            if (savedModel) {
                this.geminiModel = savedModel;
            }
        } catch (e) {
            console.warn('localStorage access unavailable:', e);
        }
    }

    @wire(getRecentLogs)
    wiredLogs({ error, data }) {
        if (data) {
            this.recentLogs = data.map(log => ({
                label: `${log.operation} - ${log.status} (${log.logUser})`,
                value: log.id,
                ...log
            }));
            if (this.recentLogs.length > 0 && !this.selectedLogId) {
                this.selectedLogId = this.recentLogs[0].value;
            }
        } else if (error) {
            console.error('Error fetching recent logs', error);
        }
    }

    get recentLogsCount() {
        return this.recentLogs ? this.recentLogs.length : 0;
    }

    get isAnalyzing() {
        return this.isAnalyzingSingle || this.isAnalyzingMulti || this.isAnalyzingRaw;
    }

    // ==========================================
    // Flow Selection & Landing Navigation
    // ==========================================
    handleOpenTimeAnalysisFlow() {
        this.selectedAppFlow = 'timeAnalysis';
        this.uiError = '';
    }

    handleOpenRawParserFlow() {
        this.selectedAppFlow = 'rawParser';
        this.uiError = '';
    }

    handleBackToFlowSelection() {
        this.selectedAppFlow = null;
        this.uiError = '';
    }

    handleSelectWindowMinutes(event) {
        const mins = parseInt(event.currentTarget.dataset.minutes, 10);
        if (mins) {
            this.selectedWindowMinutes = mins;
        }
    }

    handleSelectOverviewTab(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.activeOverviewTab = tab;
        }
    }

    // Dropdown selection
    handleLogSelect(event) {
        this.selectedLogId = event.detail.value;
        this.uiError = '';
    }

    handleRawLogChange(event) {
        this.rawLogInput = event.target.value;
        this.uiError = '';
    }

    dismissUiError() {
        this.uiError = '';
    }

    // ==========================================
    // Option 1: Log Analysis by Time Window
    // ==========================================
    handleAnalyzeUserRecentLogs() {
        this.isAnalyzingMulti = true;
        this.isDrilledDownToSingleLog = false;
        this.aiFix = null;
        this.uiError = '';

        analyzeUserRecentLogs({
            selectedLogId: this.selectedLogId || null,
            windowMinutes: this.selectedWindowMinutes || 5
        })
            .then(result => {
                this.multiLogResult = result;
                this.isMultiLogMode = true;
                this.activeOverviewTab = 'grouped';
                this.analysisResult = result.combinedParseResult;
                this.isAnalyzingMulti = false;
            })
            .catch(error => {
                this.uiError = error.body ? error.body.message : error.message;
                this.isAnalyzingMulti = false;
            });
    }

    handleAnalyzeSelected() {
        if (!this.selectedLogId) {
            this.uiError = 'Please select an Apex Log from the dropdown.';
            return;
        }

        this.isAnalyzingSingle = true;
        this.isMultiLogMode = false;
        this.isDrilledDownToSingleLog = false;
        this.multiLogResult = null;
        this.aiFix = null;
        this.uiError = '';

        analyzeLogById({ logId: this.selectedLogId })
            .then(result => {
                this.analysisResult = result;
                this.isAnalyzingSingle = false;
            })
            .catch(error => {
                this.uiError = error.body ? error.body.message : error.message;
                this.isAnalyzingSingle = false;
            });
    }

    // ==========================================
    // Option 2: Raw Log Parser
    // ==========================================
    handleAnalyzeRaw() {
        if (!this.rawLogInput || !this.rawLogInput.trim()) {
            this.uiError = 'Please paste debug log text before clicking Parse.';
            return;
        }

        this.isAnalyzingRaw = true;
        this.isMultiLogMode = false;
        this.multiLogResult = null;
        this.aiFix = null;
        this.uiError = '';

        analyzeRawLog({ rawLogText: this.rawLogInput })
            .then(result => {
                this.analysisResult = result;
                this.isAnalyzingRaw = false;
            })
            .catch(error => {
                this.uiError = error.body ? error.body.message : error.message;
                this.isAnalyzingRaw = false;
            });
    }

    // ==========================================
    // Navigation & Reset Handlers
    // ==========================================
    handleResetToLanding() {
        this.analysisResult = null;
        this.multiLogResult = null;
        this.isMultiLogMode = false;
        this.isDrilledDownToSingleLog = false;
        this.selectedAppFlow = null;
        this.aiFix = null;
        this.uiError = '';
        this.collapsedNodeIds = new Set();
        this.treeSearchQuery = '';
    }

    handleBackToTransactionGroups() {
        this.isDrilledDownToSingleLog = false;
        this.analysisResult = this.multiLogResult ? this.multiLogResult.combinedParseResult : null;
    }

    handleAnalyzeSpecificLog(event) {
        const logId = event.currentTarget.dataset.id;
        if (!logId) return;

        let found = null;
        if (this.multiLogResult && this.multiLogResult.logSummaries) {
            found = this.multiLogResult.logSummaries.find(l => l.logId === logId);
        }

        if (found && found.parseResult) {
            this.selectedLogId = logId;
            this.analysisResult = found.parseResult;
            this.isDrilledDownToSingleLog = true;
            this.aiFix = null;
            this.uiError = '';
            this.collapsedNodeIds = new Set();
        } else {
            this.selectedLogId = logId;
            this.isAnalyzingSingle = true;
            analyzeLogById({ logId: logId })
                .then(result => {
                    this.analysisResult = result;
                    this.isDrilledDownToSingleLog = true;
                    this.isAnalyzingSingle = false;
                    this.collapsedNodeIds = new Set();
                })
                .catch(err => {
                    this.uiError = err.body ? err.body.message : err.message;
                    this.isAnalyzingSingle = false;
                });
        }
    }

    handleAnalyzeTransactionGroup(event) {
        const grpId = event.currentTarget.dataset.groupid;
        if (!grpId || !this.multiLogResult) return;

        const grp = (this.multiLogResult.transactionGroups || []).find(g => g.groupId === grpId);
        if (grp && grp.logs && grp.logs.length > 0) {
            // Drill down into parent log of transaction group
            const parentLog = grp.logs[0];
            this.handleAnalyzeSpecificLog({ currentTarget: { dataset: { id: parentLog.logId } } });
        }
    }

    dismissTraceNotice() {
        this.showTraceNotice = false;
    }

    // ==========================================
    // AI Fix Generation (Per-Error Support)
    // ==========================================
    handleGenerateAIFix() {
        if (!this.analysisResult) return;
        const err = this.analysisResult.targetError || this.analysisResult.error;
        if (!err) return;
        this.triggerAIFixForError(err);
    }

    handleGenerateAIFixForSpecificError(event) {
        const errId = event.currentTarget.dataset.id;
        if (!this.analysisResult) return;

        let targetErr = null;
        if (this.analysisResult.allErrors) {
            targetErr = this.analysisResult.allErrors.find(e => e.id === errId);
        }
        if (!targetErr && this.analysisResult.handledErrors) {
            targetErr = this.analysisResult.handledErrors.find(e => e.id === errId);
        }
        if (!targetErr) {
            targetErr = this.analysisResult.targetError || this.analysisResult.error;
        }

        if (targetErr) {
            this.activeFixingErrorId = targetErr.id;
            this.triggerAIFixForError(targetErr);
        }
    }

    triggerAIFixForError(err) {
        this.isGeneratingFix = true;
        this.uiError = '';

        const warnings = (this.analysisResult.soqlWarnings || []).map(w => w.message);

        requestAIFixWithConfig({
            exceptionType: err.exceptionType || 'Exception',
            errorMessage: err.errorMessage || 'Runtime error',
            className: err.className || 'ApexClass',
            lineNumber: err.lineNumber || 1,
            surroundingCode: err.logLine || '',
            warnings: warnings,
            apiKey: this.geminiApiKey || null,
            modelName: this.geminiModel || 'gemini-3.8-flash'
        })
            .then(fix => {
                this.aiFix = fix;
                this.isGeneratingFix = false;
                this.activeFixingErrorId = '';
                // Smooth scroll to AI fix card
                setTimeout(() => {
                    const el = this.template.querySelector('.ai-fix-card');
                    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }, 100);
            })
            .catch(error => {
                this.uiError = error.body ? error.body.message : error.message;
                this.isGeneratingFix = false;
                this.activeFixingErrorId = '';
            });
    }

    handleCopyFix() {
        if (!this.aiFix || !this.aiFix.fixedCode) return;

        try {
            navigator.clipboard.writeText(this.aiFix.fixedCode);
            this.isCopied = true;
            setTimeout(() => {
                this.isCopied = false;
            }, 3000);
        } catch (err) {
            console.error('Clipboard copy failed:', err);
        }
    }

    get copyBtnLabel() {
        return this.isCopied ? '✓ Copied to Clipboard!' : '📋 Copy Fix';
    }

    get copyBtnClass() {
        return this.isCopied ? 'btn btn-copy copied' : 'btn btn-copy';
    }

    // ==========================================
    // Gemini Settings Modal
    // ==========================================
    handleOpenGeminiModal() {
        this.showGeminiModal = true;
        this.geminiTestStatus = '';
    }

    handleCloseGeminiModal() {
        this.showGeminiModal = false;
    }

    handleApiKeyChange(event) {
        this.geminiApiKey = event.target.value;
    }

    handleModelChange(event) {
        this.geminiModel = event.detail.value;
    }

    handleTogglePassword() {
        this.showPassword = !this.showPassword;
    }

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    get passwordToggleIcon() {
        return this.showPassword ? '🙈' : '👁️';
    }

    get geminiModelOptions() {
        return [
            { label: 'Gemini 3.8 Flash (Default / High Speed)', value: 'gemini-3.8-flash' },
            { label: 'Gemini 1.5 Flash (Fast & Lightweight)', value: 'gemini-1.5-flash' },
            { label: 'Gemini 1.5 Pro (Deep Reasoning)', value: 'gemini-1.5-pro' }
        ];
    }

    handleSaveGeminiKey() {
        try {
            if (this.geminiApiKey) {
                localStorage.setItem('apex_ai_gemini_key', this.geminiApiKey.trim());
            } else {
                localStorage.removeItem('apex_ai_gemini_key');
            }
            if (this.geminiModel) {
                localStorage.setItem('apex_ai_gemini_model', this.geminiModel);
            }
            this.showGeminiModal = false;
        } catch (e) {
            console.warn('Could not save to localStorage:', e);
            this.showGeminiModal = false;
        }
    }

    handleTestGemini() {
        if (!this.geminiApiKey) {
            this.geminiTestStatus = 'Please enter an API Key first.';
            this.isGeminiTestSuccess = false;
            return;
        }

        this.isTestingConnection = true;
        this.geminiTestStatus = '';

        testGeminiConnection({ apiKey: this.geminiApiKey.trim(), modelName: this.geminiModel })
            .then(res => {
                this.geminiTestStatus = res;
                this.isGeminiTestSuccess = true;
                this.isTestingConnection = false;
            })
            .catch(err => {
                this.geminiTestStatus = err.body ? err.body.message : err.message;
                this.isGeminiTestSuccess = false;
                this.isTestingConnection = false;
            });
    }

    get testStatusClass() {
        return this.isGeminiTestSuccess ? 'test-status success-text' : 'test-status error-text';
    }

    // ==========================================
    // Call Tree Interactions & Search
    // ==========================================
    handleTreeSearch(event) {
        this.treeSearchQuery = (event.target.value || '').trim().toLowerCase();
    }

    handleToggleNode(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        if (this.collapsedNodeIds.has(id)) {
            this.collapsedNodeIds.delete(id);
        } else {
            this.collapsedNodeIds.add(id);
        }
        this.collapsedNodeIds = new Set(this.collapsedNodeIds);
    }

    handleExpandAll() {
        this.collapsedNodeIds = new Set();
    }

    handleCollapseAll() {
        if (!this.analysisResult || !this.analysisResult.flatCallTree) return;
        const setIds = new Set();
        for (const node of this.analysisResult.flatCallTree) {
            if (node.hasChildren) {
                setIds.add(node.id);
            }
        }
        this.collapsedNodeIds = setIds;
    }

    handleJumpToError() {
        if (!this.analysisResult || !this.analysisResult.flatCallTree) return;

        // Prioritize stopPoint / unhandled error frame, otherwise first error node
        let target = this.analysisResult.flatCallTree.find(n => n.isStopPoint);
        if (!target) {
            target = this.analysisResult.flatCallTree.find(n => n.hasError && n.isUnhandled);
        }
        if (!target) {
            target = this.analysisResult.flatCallTree.find(n => n.hasError);
        }
        if (!target) return;

        // Uncollapse ancestors
        let cur = target;
        while (cur && cur.parentId) {
            this.collapsedNodeIds.delete(cur.parentId);
            cur = this.analysisResult.flatCallTree.find(n => n.id === cur.parentId);
        }
        this.collapsedNodeIds = new Set(this.collapsedNodeIds);

        // Scroll to target row
        setTimeout(() => {
            const el = this.template.querySelector(`[data-id="${target.id}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                el.classList.add('node-highlight-pulse');
                setTimeout(() => el.classList.remove('node-highlight-pulse'), 2500);
            }
        }, 120);
    }

    get hasTreeNodes() {
        return this.visibleTreeNodes.length > 0;
    }

    get hasErrorInTree() {
        if (!this.analysisResult || !this.analysisResult.flatCallTree) return false;
        return this.analysisResult.flatCallTree.some(n => n.hasError);
    }

    get visibleTreeNodes() {
        if (!this.analysisResult || !this.analysisResult.flatCallTree) return [];
        const query = this.treeSearchQuery;
        const collapsed = this.collapsedNodeIds;
        const hiddenParentIds = new Set();
        const resultNodes = [];

        for (const node of this.analysisResult.flatCallTree) {
            const isHidden = hiddenParentIds.has(node.parentId);
            if (isHidden) {
                hiddenParentIds.add(node.id);
                continue;
            }

            if (collapsed.has(node.id)) {
                hiddenParentIds.add(node.id);
            }

            if (query) {
                const matchClass = (node.className || '').toLowerCase().includes(query);
                const matchMethod = (node.methodName || '').toLowerCase().includes(query);
                const matchSig = (node.signature || '').toLowerCase().includes(query);
                if (!matchClass && !matchMethod && !matchSig) {
                    continue;
                }
            }

            const isExp = !collapsed.has(node.id);
            const indentPx = Math.min(240, (node.depth || 1) * 20);

            let typeBadgeClass = 'badge-node-type badge-type-method';
            if (node.nodeType === 'TRIGGER') typeBadgeClass = 'badge-node-type badge-type-trigger';
            else if (node.nodeType === 'CODE_UNIT') typeBadgeClass = 'badge-node-type badge-type-codeunit';

            let rowClass = 'tree-node-row';
            if (node.isStopPoint) {
                rowClass += ' node-row-stoppoint';
            } else if (node.hasError && node.isUnhandled) {
                rowClass += ' node-row-unhandled';
            } else if (node.hasError && node.isHandled) {
                rowClass += ' node-row-handled';
            } else if (node.hasError) {
                rowClass += ' node-row-error';
            }
            if (node.isReentrant) {
                rowClass += ' node-row-reentrant';
            }

            resultNodes.push({
                ...node,
                isExpanded: isExp,
                indentStyle: `padding-left: ${indentPx}px;`,
                formattedDuration: node.durationMs > 0 ? `${node.durationMs.toFixed(1)}ms` : '',
                typeBadgeClass: typeBadgeClass,
                rowClass: rowClass
            });
        }
        return resultNodes;
    }

    // ==========================================
    // View State Getters
    // ==========================================
    get isFlowSelectionView() {
        return !this.analysisResult && !this.multiLogResult && !this.selectedAppFlow;
    }

    get isTimeAnalysisSetupView() {
        return !this.analysisResult && !this.multiLogResult && this.selectedAppFlow === 'timeAnalysis';
    }

    get isRawParserSetupView() {
        return !this.analysisResult && !this.multiLogResult && this.selectedAppFlow === 'rawParser';
    }

    get hasActiveAnalysis() {
        return !!(this.analysisResult || this.isMultiLogMode);
    }

    get isShowingSingleLogAnalysis() {
        return (this.analysisResult && !this.isMultiLogMode) || this.isDrilledDownToSingleLog;
    }

    get isShowingMultiLogOverview() {
        return this.isMultiLogMode && !this.isDrilledDownToSingleLog;
    }

    get showTraceFlagBanner() {
        return this.analysisResult && !this.analysisResult.hasMethodTracing && this.showTraceNotice;
    }

    // Time window selector pills
    get windowOptions() {
        const selected = this.selectedWindowMinutes || 5;
        return [
            { minutes: 5, label: '5 Mins (Default)', isSelected: selected === 5, pillClass: selected === 5 ? 'pill-choice active' : 'pill-choice' },
            { minutes: 15, label: '15 Mins', isSelected: selected === 15, pillClass: selected === 15 ? 'pill-choice active' : 'pill-choice' },
            { minutes: 30, label: '30 Mins', isSelected: selected === 30, pillClass: selected === 30 ? 'pill-choice active' : 'pill-choice' },
            { minutes: 60, label: '1 Hour', isSelected: selected === 60, pillClass: selected === 60 ? 'pill-choice active' : 'pill-choice' }
        ];
    }

    // 3 Tab Getters
    get isTabGroupedActive() {
        return this.activeOverviewTab === 'grouped';
    }

    get isTabChronologicalActive() {
        return this.activeOverviewTab === 'chronological';
    }

    get isTabUnrelatedActive() {
        return this.activeOverviewTab === 'unrelated';
    }

    get tabGroupedClass() {
        return this.activeOverviewTab === 'grouped' ? 'tab-item active' : 'tab-item';
    }

    get tabChronologicalClass() {
        return this.activeOverviewTab === 'chronological' ? 'tab-item active' : 'tab-item';
    }

    get tabUnrelatedClass() {
        return this.activeOverviewTab === 'unrelated' ? 'tab-item active' : 'tab-item';
    }

    // Tab 1: Grouped Transactions
    get transactionGroupsCount() {
        if (!this.multiLogResult || !this.multiLogResult.transactionGroups) return 0;
        return this.multiLogResult.transactionGroups.filter(g => g.isCausallyLinked).length;
    }

    get transactionGroupsView() {
        if (!this.multiLogResult || !this.multiLogResult.transactionGroups) return [];
        return this.multiLogResult.transactionGroups
            .filter(grp => grp.isCausallyLinked)
            .map(grp => ({
                ...grp,
                badgeLabel: '⏱️ ' + grp.groupId.replace('tx_', 'TX-'),
                logs: (grp.logs || []).map(log => this.formatLogCard(log))
            }));
    }

    // Tab 2: Chronological List View
    get totalLogsCount() {
        return this.multiLogResult && this.multiLogResult.chronologicalLogs ? this.multiLogResult.chronologicalLogs.length : 0;
    }

    get chronologicalLogsView() {
        if (!this.multiLogResult || !this.multiLogResult.chronologicalLogs) return [];
        return this.multiLogResult.chronologicalLogs.map(log => this.formatLogCard(log));
    }

    // Tab 3: Others (Unrelated Logs)
    get unrelatedLogsCount() {
        return this.multiLogResult && this.multiLogResult.unrelatedLogs ? this.multiLogResult.unrelatedLogs.length : 0;
    }

    get unrelatedLogsView() {
        if (!this.multiLogResult || !this.multiLogResult.unrelatedLogs) return [];
        return this.multiLogResult.unrelatedLogs.map(log => this.formatLogCard(log));
    }

    formatLogCard(log) {
        const isSuccess = log.status === 'Success';
        return {
            ...log,
            isChildLog: !!log.parentJobId,
            cardClass: log.hasError ? 'tx-log-card log-card-error' : 'tx-log-card log-card-success',
            statusChipClass: isSuccess ? 'status-pill status-pill-success' : 'status-pill status-pill-error',
            statusLabel: isSuccess ? '✓ SUCCESS' : '✕ ERROR'
        };
    }

    // Diagnostics & Error Classification
    get hasError() {
        return !!(this.analysisResult && this.analysisResult.hasError);
    }

    get targetError() {
        return this.analysisResult ? (this.analysisResult.targetError || (this.analysisResult.hasError ? this.analysisResult.error : null)) : null;
    }

    get hasTargetError() {
        return !!this.targetError;
    }

    get handledErrors() {
        if (!this.analysisResult || !this.analysisResult.handledErrors) return [];
        return this.analysisResult.handledErrors.map(err => ({
            ...err,
            isCurrentlyFixing: this.isGeneratingFix && this.activeFixingErrorId === err.id
        }));
    }

    get hasHandledErrors() {
        return this.handledErrors.length > 0;
    }

    get handledErrorsCount() {
        return this.handledErrors.length;
    }

    get errorDetail() {
        return this.targetError || (this.analysisResult ? this.analysisResult.error : null);
    }

    // Limits & Diagnostics
    get limits() {
        return this.analysisResult && this.analysisResult.limits ? this.analysisResult.limits : {
            soqlQueries: 0,
            maxSoql: 100,
            dmlStatements: 0,
            maxDml: 150,
            cpuTimeMs: 0,
            maxCpuTimeMs: 10000
        };
    }

    get soqlPercent() {
        const cur = this.limits.soqlQueries || 0;
        const max = this.limits.maxSoql || 100;
        return Math.min(100, Math.round((cur / max) * 100));
    }

    get dmlPercent() {
        const cur = this.limits.dmlStatements || 0;
        const max = this.limits.maxDml || 150;
        return Math.min(100, Math.round((cur / max) * 100));
    }

    get cpuPercent() {
        const cur = this.limits.cpuTimeMs || 0;
        const max = this.limits.maxCpuTimeMs || 10000;
        return Math.min(100, Math.round((cur / max) * 100));
    }

    get soqlProgressStyle() {
        return `width: ${this.soqlPercent}%;`;
    }

    get dmlProgressStyle() {
        return `width: ${this.dmlPercent}%;`;
    }

    get cpuProgressStyle() {
        return `width: ${this.cpuPercent}%;`;
    }

    get soqlWarnings() {
        return this.analysisResult ? (this.analysisResult.soqlWarnings || []) : [];
    }

    get stages() {
        if (!this.analysisResult || !this.analysisResult.stages) return [];
        return this.analysisResult.stages.map((stg, idx) => {
            const isErr = stg.status === 'ERROR';
            return {
                ...stg,
                stageOrder: idx + 1,
                circleClass: isErr ? 'step-circle step-error' : 'step-circle step-success',
                icon: isErr ? '✕' : '✓'
            };
        });
    }

    get asyncTraces() {
        return this.analysisResult ? (this.analysisResult.asyncTraces || []) : [];
    }

    get primaryExecutionTitle() {
        if (this.selectedLogId && this.recentLogs) {
            const match = this.recentLogs.find(l => l.value === this.selectedLogId);
            if (match) {
                return `${match.operation} (${match.logUser})`;
            }
        }
        return 'Synchronous Apex Execution';
    }
}
