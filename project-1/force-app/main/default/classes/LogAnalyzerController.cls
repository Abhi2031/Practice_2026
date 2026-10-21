public with sharing class LogAnalyzerController {

    public class LogOption {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String logUser { get; set; }
        @AuraEnabled public String operation { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer logLength { get; set; }
        @AuraEnabled public Datetime startTime { get; set; }
    }

    public class TransactionGroup {
        @AuraEnabled public String groupId { get; set; }
        @AuraEnabled public String groupTitle { get; set; }
        @AuraEnabled public Boolean isCausallyLinked { get; set; }
        @AuraEnabled public Integer totalLogsCount { get; set; }
        @AuraEnabled public List<SingleLogSummary> logs { get; set; }
        @AuraEnabled public Datetime startTime { get; set; }
        @AuraEnabled public Datetime endTime { get; set; }
        @AuraEnabled public String formattedTimeSpan { get; set; }
        @AuraEnabled public Long durationMs { get; set; }

        public TransactionGroup() {
            this.logs = new List<SingleLogSummary>();
            this.isCausallyLinked = false;
            this.totalLogsCount = 0;
            this.durationMs = 0L;
        }
    }

    public class MultiLogResult {
        @AuraEnabled public Integer totalLogsCount { get; set; }
        @AuraEnabled public String userName { get; set; }
        @AuraEnabled public Integer windowMinutes { get; set; }
        @AuraEnabled public LogParserService.ParseResult combinedParseResult { get; set; }
        @AuraEnabled public List<TransactionGroup> transactionGroups { get; set; }
        @AuraEnabled public List<SingleLogSummary> chronologicalLogs { get; set; }
        @AuraEnabled public List<SingleLogSummary> unrelatedLogs { get; set; }
        @AuraEnabled public List<SingleLogSummary> logSummaries { get; set; }
        @AuraEnabled public Boolean hasError { get; set; }
        @AuraEnabled public LogParserService.ErrorDetail primaryError { get; set; }
        @AuraEnabled public String summaryMessage { get; set; }

        public MultiLogResult() {
            this.transactionGroups = new List<TransactionGroup>();
            this.chronologicalLogs = new List<SingleLogSummary>();
            this.unrelatedLogs = new List<SingleLogSummary>();
            this.logSummaries = new List<SingleLogSummary>();
            this.hasError = false;
            this.windowMinutes = 5;
        }
    }

    public class SingleLogSummary {
        @AuraEnabled public Id logId { get; set; }
        @AuraEnabled public String operation { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer logLength { get; set; }
        @AuraEnabled public Datetime startTime { get; set; }
        @AuraEnabled public String formattedTime { get; set; }
        @AuraEnabled public Long relativeOffsetMs { get; set; }
        @AuraEnabled public Integer durationMs { get; set; }
        @AuraEnabled public Integer soqlCount { get; set; }
        @AuraEnabled public Integer dmlCount { get; set; }
        @AuraEnabled public Integer cpuTimeMs { get; set; }
        @AuraEnabled public Boolean hasError { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public List<String> enqueuedJobIds { get; set; }
        @AuraEnabled public String parentJobId { get; set; }
        @AuraEnabled public LogParserService.ParseResult parseResult { get; set; }

        public SingleLogSummary() {
            this.enqueuedJobIds = new List<String>();
            this.hasError = false;
            this.relativeOffsetMs = 0;
            this.durationMs = 0;
        }
    }

    /**
     * Retrieve recent ApexLog records from current org
     */
    @AuraEnabled(cacheable=true)
    public static List<LogOption> getRecentLogs() {
        List<LogOption> options = new List<LogOption>();
        try {
            List<ApexLog> logs = [
                SELECT Id, LogUserId, LogUser.Name, Operation, Status, LogLength, StartTime
                FROM ApexLog
                ORDER BY StartTime DESC
                LIMIT 50
            ];
            for (ApexLog l : logs) {
                LogOption opt = new LogOption();
                opt.id = l.Id;
                opt.userId = l.LogUserId;
                opt.logUser = l.LogUser != null ? l.LogUser.Name : 'System User';
                opt.operation = l.Operation;
                opt.status = l.Status;
                opt.logLength = l.LogLength;
                opt.startTime = l.StartTime;
                options.add(opt);
            }
        } catch (Exception ex) {
            System.debug('Error querying ApexLog: ' + ex.getMessage());
        }
        return options;
    }

    /**
     * Retrieve valid API Session ID using SessionIdHelper Visualforce page
     */
    public static String getApiSessionId() {
        try {
            PageReference pr = Page.SessionIdHelper;
            String content = pr.getContent().toString();
            String sid = content.substringBetween('START_SESSION_ID', 'END_SESSION_ID');
            if (String.isNotBlank(sid)) {
                return sid.trim();
            }
        } catch (Exception e) {
            System.debug('SessionIdHelper fallback: ' + e.getMessage());
        }
        return UserInfo.getSessionId();
    }

    /**
     * Button 1: Analyze a single selected ApexLog by Id
     */
    @AuraEnabled
    public static LogParserService.ParseResult analyzeLogById(Id logId) {
        if (logId == null) {
            throw new AuraHandledException('Please select an Apex Log from the dropdown list.');
        }

        String logBody = '';
        try {
            logBody = fetchApexLogBody(logId);
        } catch(Exception e) {
            throw new AuraHandledException('Unable to fetch Apex Log body: ' + e.getMessage());
        }

        if (String.isBlank(logBody)) {
            throw new AuraHandledException('The selected Apex Log contains no content or body.');
        }

        return LogParserService.parseLog(logBody);
    }

    /**
     * Button 2: Fetch and aggregate all logs related to the target user generated within the last 5 minutes
     */
    @AuraEnabled
    public static MultiLogResult analyzeUserRecentLogs(Id selectedLogId, Integer windowMinutes) {
        Integer windowMins = (windowMinutes != null && windowMinutes > 0) ? windowMinutes : 5;

        MultiLogResult multi = new MultiLogResult();
        multi.windowMinutes = windowMins;
        multi.logSummaries = new List<SingleLogSummary>();
        multi.chronologicalLogs = new List<SingleLogSummary>();
        multi.unrelatedLogs = new List<SingleLogSummary>();
        multi.combinedParseResult = new LogParserService.ParseResult();
        multi.hasError = false;

        // Resolve target user
        Id targetUserId = UserInfo.getUserId();
        if (selectedLogId != null) {
            List<ApexLog> sel = [SELECT LogUserId FROM ApexLog WHERE Id = :selectedLogId LIMIT 1];
            if (!sel.isEmpty() && sel[0].LogUserId != null) {
                targetUserId = sel[0].LogUserId;
            }
        }

        List<User> userList = [SELECT Name FROM User WHERE Id = :targetUserId LIMIT 1];
        multi.userName = !userList.isEmpty() ? userList[0].Name : 'Target User';

        // Query logs generated within the selected time window
        Datetime cutoffTime = Datetime.now().addMinutes(-windowMins);
        List<ApexLog> logs = [
            SELECT Id, LogUserId, LogUser.Name, Operation, Status, LogLength, StartTime, DurationMilliseconds, RequestIdentifier
            FROM ApexLog
            WHERE LogUserId = :targetUserId AND StartTime >= :cutoffTime
            ORDER BY StartTime ASC
            LIMIT 25
        ];

        multi.totalLogsCount = logs.size();
        if (logs.isEmpty()) {
            multi.summaryMessage = 'No logs found for ' + multi.userName + ' in the selected ' + windowMins + '-minute window.';
            return multi;
        }

        multi.summaryMessage = 'Found ' + logs.size() + ' logs for ' + multi.userName + ' generated within the last ' + windowMins + ' minutes.';

        Integer totalSoql = 0;
        Integer totalDml = 0;
        Integer totalCpu = 0;
        Datetime baseTime = !logs.isEmpty() ? logs[0].StartTime : null;
        List<SingleLogSummary> allSummaries = new List<SingleLogSummary>();

        for (ApexLog l : logs) {
            SingleLogSummary sum = new SingleLogSummary();
            sum.logId = l.Id;
            sum.operation = l.Operation;
            sum.status = l.Status;
            sum.logLength = l.LogLength;
            sum.startTime = l.StartTime;
            sum.formattedTime = l.StartTime != null ? l.StartTime.format('HH:mm:ss.SSS') : '';
            sum.relativeOffsetMs = (l.StartTime != null && baseTime != null) ? l.StartTime.getTime() - baseTime.getTime() : 0;
            sum.durationMs = l.DurationMilliseconds != null ? l.DurationMilliseconds : 0;

            String body = '';
            try {
                body = fetchApexLogBody(l.Id);
            } catch (Exception ex) {
                body = '';
            }

            if (String.isNotBlank(body)) {
                LogParserService.ParseResult pr = LogParserService.parseLog(body);
                sum.parseResult = pr;
                sum.soqlCount = pr.limits.soqlQueries;
                sum.dmlCount = pr.limits.dmlStatements;
                sum.cpuTimeMs = pr.limits.cpuTimeMs;
                sum.hasError = pr.hasError;
                sum.enqueuedJobIds = pr.enqueuedJobIds;

                if (pr.hasError && pr.error != null) {
                    sum.errorMessage = pr.error.exceptionType + ': ' + pr.error.errorMessage;
                    if (!multi.hasError) {
                        multi.hasError = true;
                        multi.primaryError = pr.error;
                    }
                }

                totalSoql += pr.limits.soqlQueries;
                totalDml += pr.limits.dmlStatements;
                totalCpu += pr.limits.cpuTimeMs;

                // Add stages
                for (LogParserService.OrderOfExecutionStage stg : pr.stages) {
                    stg.stageName = '[' + l.Operation + '] ' + stg.stageName;
                    multi.combinedParseResult.stages.add(stg);
                }

                // Add warnings
                multi.combinedParseResult.soqlWarnings.addAll(pr.soqlWarnings);

                // Add async traces
                multi.combinedParseResult.asyncTraces.addAll(pr.asyncTraces);
            }
            allSummaries.add(sum);
        }

        // Map JobId -> Parent Log
        Map<String, SingleLogSummary> jobToParent = new Map<String, SingleLogSummary>();
        for (SingleLogSummary s : allSummaries) {
            for (String jobId : s.enqueuedJobIds) {
                jobToParent.put(jobId, s);
            }
        }

        // Identify parent-child causal links
        Map<Id, List<SingleLogSummary>> parentToChildren = new Map<Id, List<SingleLogSummary>>();
        Set<Id> childIds = new Set<Id>();

        for (SingleLogSummary child : allSummaries) {
            SingleLogSummary parent = null;
            for (String jId : jobToParent.keySet()) {
                if (String.isNotBlank(child.operation) && child.operation.contains(jId)) {
                    parent = jobToParent.get(jId);
                    child.parentJobId = jId;
                    break;
                }
            }

            if (parent != null && parent.logId != child.logId) {
                childIds.add(child.logId);
                if (!parentToChildren.containsKey(parent.logId)) {
                    parentToChildren.put(parent.logId, new List<SingleLogSummary>());
                }
                parentToChildren.get(parent.logId).add(child);
            }
        }

        // Group into Transaction Groups: Transaction 1, Transaction 2... and Others (Unrelated)
        List<TransactionGroup> groups = new List<TransactionGroup>();
        TransactionGroup othersGroup = new TransactionGroup();
        othersGroup.groupId = 'tx_others';
        othersGroup.groupTitle = 'Others (Unrelated Transactions - Last ' + windowMins + ' Mins)';
        othersGroup.isCausallyLinked = false;

        Integer txIndex = 1;

        for (SingleLogSummary s : allSummaries) {
            // Skip if this is a child log in an existing chain
            if (childIds.contains(s.logId)) {
                continue;
            }

            // If it has children (causally linked transaction flow)
            if (parentToChildren.containsKey(s.logId) && !parentToChildren.get(s.logId).isEmpty()) {
                TransactionGroup tg = new TransactionGroup();
                tg.groupId = 'tx_' + txIndex;
                tg.groupTitle = 'Transaction ' + txIndex + ': ' + s.operation + ' Flow (' + (1 + parentToChildren.get(s.logId).size()) + ' Linked Logs)';
                tg.isCausallyLinked = true;
                tg.logs.add(s);
                tg.logs.addAll(parentToChildren.get(s.logId));
                tg.totalLogsCount = tg.logs.size();

                calculateGroupTimeSpan(tg);
                groups.add(tg);
                txIndex++;
            } else {
                // Unrelated log: Check age against cutoffTime
                Boolean isWithinWindow = s.startTime != null && s.startTime >= cutoffTime;
                if (isWithinWindow) {
                    othersGroup.logs.add(s);
                }
            }
        }

        if (!othersGroup.logs.isEmpty()) {
            othersGroup.totalLogsCount = othersGroup.logs.size();
            calculateGroupTimeSpan(othersGroup);
            groups.add(othersGroup);
        }

        multi.transactionGroups = groups;
        multi.chronologicalLogs = allSummaries;
        multi.unrelatedLogs = othersGroup.logs;
        multi.logSummaries = allSummaries;

        multi.combinedParseResult.limits.soqlQueries = totalSoql;
        multi.combinedParseResult.limits.dmlStatements = totalDml;
        multi.combinedParseResult.limits.cpuTimeMs = totalCpu;
        multi.combinedParseResult.hasError = multi.hasError;
        multi.combinedParseResult.error = multi.primaryError;
        multi.combinedParseResult.logStatus = multi.hasError ? 'Failed' : 'Success';

        return multi;
    }

    private static void calculateGroupTimeSpan(TransactionGroup tg) {
        if (tg.logs == null || tg.logs.isEmpty()) {
            return;
        }
        Datetime minStart = null;
        Datetime maxEnd = null;
        for (SingleLogSummary l : tg.logs) {
            if (l.startTime != null) {
                if (minStart == null || l.startTime < minStart) {
                    minStart = l.startTime;
                }
                Integer durSec = l.durationMs != null && l.durationMs > 0 ? (l.durationMs / 1000) : 0;
                Datetime lEnd = l.startTime.addSeconds(durSec);
                if (maxEnd == null || lEnd > maxEnd) {
                    maxEnd = lEnd;
                }
            }
        }
        tg.startTime = minStart;
        tg.endTime = maxEnd;
        if (minStart != null && maxEnd != null) {
            Long spanMs = maxEnd.getTime() - minStart.getTime();
            tg.durationMs = spanMs > 0 ? spanMs : (tg.logs[0].durationMs != null ? tg.logs[0].durationMs : 0);
            Decimal spanSec = Decimal.valueOf(tg.durationMs) / 1000.0;
            tg.formattedTimeSpan = minStart.format('HH:mm:ss') + ' - ' + maxEnd.format('HH:mm:ss') + ' (' + spanSec.setScale(2) + 's)';
        } else if (minStart != null) {
            tg.formattedTimeSpan = minStart.format('HH:mm:ss');
        }
    }

    /**
     * Parse raw text input
     */
    @AuraEnabled
    public static LogParserService.ParseResult analyzeRawLog(String rawLogText) {
        if (String.isBlank(rawLogText)) {
            throw new AuraHandledException('Raw log text cannot be blank. Please paste your Apex debug log.');
        }
        return LogParserService.parseLog(rawLogText);
    }

    /**
     * Test Google Gemini connection with provided API key and model
     */
    @AuraEnabled
    public static String testGeminiConnection(String apiKey, String modelName) {
        return CloudAIService.testConnection(apiKey, modelName);
    }

    /**
     * Request AI fix (Backward compatible)
     */
    @AuraEnabled
    public static CloudAIService.AIAnalysisResponse requestAIFix(
        String exceptionType,
        String errorMessage,
        String className,
        Integer lineNumber,
        String surroundingCode,
        List<String> warnings
    ) {
        return requestAIFixWithConfig(exceptionType, errorMessage, className, lineNumber, surroundingCode, warnings, null, 'gemini-2.5-flash');
    }

    /**
     * Request AI fix with user-configured Gemini API Key and Model
     */
    @AuraEnabled
    public static CloudAIService.AIAnalysisResponse requestAIFixWithConfig(
        String exceptionType,
        String errorMessage,
        String className,
        Integer lineNumber,
        String surroundingCode,
        List<String> warnings,
        String apiKey,
        String modelName
    ) {
        CloudAIService.AIAnalysisRequest req = new CloudAIService.AIAnalysisRequest();
        req.exceptionType = exceptionType;
        req.errorMessage = errorMessage;
        req.className = className;
        req.lineNumber = lineNumber;
        req.surroundingCode = surroundingCode;
        req.warnings = warnings;

        return CloudAIService.generateFix(req, apiKey, modelName);
    }

    /**
     * Fetches real log body from Tooling API using the valid Session ID
     */
    private static String fetchApexLogBody(Id logId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(Url.getOrgDomainUrl().toExternalForm() + '/services/data/v59.0/tooling/sobjects/ApexLog/' + logId + '/Body');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + getApiSessionId());
        req.setTimeout(30000);

        Http h = new Http();
        HttpResponse res = h.send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new AuraHandledException('Tooling API returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }

    public static String getSampleErrorLog() {
        return '59.0 APEX_CODE,FINEST;APEX_PROFILING,INFO;CALLOUT,INFO;DB,INFO;SYSTEM,DEBUG;VALIDATION,INFO;VISUALFORCE,INFO;WORKFLOW,INFO\n' +
               '10:15:20.001 (1001)|EXECUTION_STARTED\n' +
               '10:15:20.002 (2002)|CODE_UNIT_STARTED|[EXTERNAL]|01q5g0000001234|AccountTrigger on Account trigger event BeforeInsert\n' +
               '10:15:20.010 (10010)|VALIDATION_RULE|[Account_Rating_Check]|PASSED\n' +
               '10:15:20.015 (15015)|METHOD_ENTRY|[15]|01p5g0000005678|AccountService.processAccounts(List<Account>)\n' +
               '10:15:20.020 (20020)|SOQL_EXECUTE_BEGIN|[24]|Aggregations:0|SELECT Id, Name FROM Contact WHERE AccountId = :tmpVar1\n' +
               '10:15:20.025 (25025)|SOQL_EXECUTE_END|[24]|Rows:1\n' +
               '10:15:20.030 (30030)|SOQL_EXECUTE_BEGIN|[24]|Aggregations:0|SELECT Id, Name FROM Contact WHERE AccountId = :tmpVar1\n' +
               '10:15:20.035 (35035)|SOQL_EXECUTE_END|[24]|Rows:1\n' +
               '10:15:20.040 (40040)|SYSTEM_METHOD_ENTRY|[35]|System.enqueueJob(Object)\n' +
               '10:15:20.045 (45045)|SYSTEM_METHOD_EXIT|[35]|7075g0000012345\n' +
               '10:15:20.050 (50050)|EXCEPTION_THROWN|[42]|System.NullPointerException: Attempt to de-reference a null object\n' +
               '10:15:20.052 (52052)|FATAL_ERROR|System.NullPointerException: Attempt to de-reference a null object\n' +
               'Class.AccountService.processAccounts: line 42, column 1\n' +
               'Class.AccountTriggerHandler.beforeInsert: line 18, column 1\n' +
               'Trigger.AccountTrigger: line 4, column 1\n' +
               '10:15:20.060 (60060)|CUMULATIVE_LIMIT_USAGE\n' +
               'Number of SOQL queries: 12 out of 100\n' +
               'Number of query rows: 15 out of 50000\n' +
               'Number of DML statements: 2 out of 150\n' +
               'Number of DML rows: 2 out of 10000\n' +
               'Maximum CPU time: 350 out of 10000\n' +
               'Maximum heap size: 12450 out of 6000000\n' +
               '10:15:20.070 (70070)|CUMULATIVE_LIMIT_USAGE_END';
    }
}
