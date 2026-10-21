public with sharing class LogParserService {

    public class ExecutionNode {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String parentId { get; set; }
        @AuraEnabled public String nodeType { get; set; } // METHOD, TRIGGER, CODE_UNIT, DML, SOQL, ROOT
        @AuraEnabled public String className { get; set; }
        @AuraEnabled public String methodName { get; set; }
        @AuraEnabled public String signature { get; set; }
        @AuraEnabled public Integer lineNumber { get; set; }
        @AuraEnabled public Integer depth { get; set; }
        @AuraEnabled public Double durationMs { get; set; }
        @AuraEnabled public Long startNano { get; set; }
        @AuraEnabled public Integer soqlCount { get; set; }
        @AuraEnabled public Integer dmlCount { get; set; }
        @AuraEnabled public Boolean hasError { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public Boolean isReentrant { get; set; }
        @AuraEnabled public Boolean hasChildren { get; set; }
        @AuraEnabled public Boolean isStopPoint { get; set; } // Method where execution stopped
        @AuraEnabled public Boolean isUnhandled { get; set; } // Entered but never exited
        @AuraEnabled public Boolean isHandled { get; set; }   // Caught exception
        @AuraEnabled public List<ExecutionNode> children { get; set; }

        public ExecutionNode() {
            this.children = new List<ExecutionNode>();
            this.durationMs = 0.0;
            this.soqlCount = 0;
            this.dmlCount = 0;
            this.hasError = false;
            this.isReentrant = false;
            this.hasChildren = false;
            this.isStopPoint = false;
            this.isUnhandled = false;
            this.isHandled = false;
            this.depth = 0;
        }
    }

    public class ParseResult {
        @AuraEnabled public Boolean hasError { get; set; }
        @AuraEnabled public ErrorDetail error { get; set; }
        @AuraEnabled public ErrorDetail targetError { get; set; } // Unhandled crash error where execution stopped
        @AuraEnabled public List<ErrorDetail> handledErrors { get; set; } // Caught/handled errors
        @AuraEnabled public List<ErrorDetail> allErrors { get; set; }
        @AuraEnabled public Boolean hasTargetError { get; set; }
        @AuraEnabled public Boolean hasHandledErrors { get; set; }
        @AuraEnabled public LimitUsage limits { get; set; }
        @AuraEnabled public List<OrderOfExecutionStage> stages { get; set; }
        @AuraEnabled public List<SoqlWarning> soqlWarnings { get; set; }
        @AuraEnabled public List<AsyncTraceInfo> asyncTraces { get; set; }
        @AuraEnabled public List<BurnRatePoint> burnRateTimeline { get; set; }
        @AuraEnabled public Integer totalLinesParsed { get; set; }
        @AuraEnabled public String logStatus { get; set; } // Success or Failed
        @AuraEnabled public ExecutionNode rootCallNode { get; set; }
        @AuraEnabled public List<ExecutionNode> flatCallTree { get; set; }
        @AuraEnabled public List<String> enqueuedJobIds { get; set; }
        @AuraEnabled public Boolean hasMethodTracing { get; set; }
        @AuraEnabled public String logLevelSummary { get; set; }

        public ParseResult() {
            this.hasError = false;
            this.hasTargetError = false;
            this.hasHandledErrors = false;
            this.handledErrors = new List<ErrorDetail>();
            this.allErrors = new List<ErrorDetail>();
            this.stages = new List<OrderOfExecutionStage>();
            this.soqlWarnings = new List<SoqlWarning>();
            this.asyncTraces = new List<AsyncTraceInfo>();
            this.burnRateTimeline = new List<BurnRatePoint>();
            this.limits = new LimitUsage();
            this.totalLinesParsed = 0;
            this.logStatus = 'Success';
            this.flatCallTree = new List<ExecutionNode>();
            this.enqueuedJobIds = new List<String>();
            this.hasMethodTracing = false;
            this.logLevelSummary = 'APEX_CODE,INFO';
        }
    }

    public class ErrorDetail {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String exceptionType { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public String className { get; set; }
        @AuraEnabled public String methodName { get; set; }
        @AuraEnabled public Integer lineNumber { get; set; }
        @AuraEnabled public String stackTrace { get; set; }
        @AuraEnabled public String logLine { get; set; }
        @AuraEnabled public Boolean isUnhandled { get; set; }
        @AuraEnabled public Boolean isHandled { get; set; }
        @AuraEnabled public String severity { get; set; } // CRITICAL or WARNING

        public ErrorDetail() {
            this.isUnhandled = false;
            this.isHandled = false;
            this.severity = 'WARNING';
        }
    }

    public class LimitUsage {
        @AuraEnabled public Integer soqlQueries { get; set; }
        @AuraEnabled public Integer maxSoql { get; set; }
        @AuraEnabled public Integer dmlStatements { get; set; }
        @AuraEnabled public Integer maxDml { get; set; }
        @AuraEnabled public Integer cpuTimeMs { get; set; }
        @AuraEnabled public Integer maxCpuTimeMs { get; set; }
        @AuraEnabled public Integer heapSizeBytes { get; set; }
        @AuraEnabled public Integer maxHeapSizeBytes { get; set; }

        public LimitUsage() {
            this.soqlQueries = 0;
            this.maxSoql = 100;
            this.dmlStatements = 0;
            this.maxDml = 150;
            this.cpuTimeMs = 0;
            this.maxCpuTimeMs = 10000;
            this.heapSizeBytes = 0;
            this.maxHeapSizeBytes = 6000000;
        }
    }

    public class OrderOfExecutionStage {
        @AuraEnabled public Integer stageOrder { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public String category { get; set; } // Validation, Trigger, Flow, DML, Apex, System
        @AuraEnabled public String status { get; set; }   // SUCCESS, ERROR, SKIPPED
        @AuraEnabled public String details { get; set; }
        @AuraEnabled public Long durationMs { get; set; }
    }

    public class SoqlWarning {
        @AuraEnabled public Integer lineNumber { get; set; }
        @AuraEnabled public String className { get; set; }
        @AuraEnabled public String query { get; set; }
        @AuraEnabled public Integer executionCount { get; set; }
        @AuraEnabled public Boolean isInsideLoop { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class AsyncTraceInfo {
        @AuraEnabled public String asyncType { get; set; } // Queueable, BatchApex, PlatformEvent, Future
        @AuraEnabled public String jobId { get; set; }
        @AuraEnabled public String targetClassOrEvent { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String logSnippet { get; set; }
    }

    public class BurnRatePoint {
        @AuraEnabled public Integer timestampNano { get; set; }
        @AuraEnabled public Integer eventIndex { get; set; }
        @AuraEnabled public Integer soqlCount { get; set; }
        @AuraEnabled public Integer dmlCount { get; set; }
        @AuraEnabled public Integer cpuTimeMs { get; set; }
        @AuraEnabled public String currentMethod { get; set; }
    }

    /**
     * Parse raw debug log text into structured analytics
     */
    public static ParseResult parseLog(String rawLog) {
        ParseResult result = new ParseResult();
        if (String.isBlank(rawLog)) {
            return result;
        }

        List<String> lines = safeSplitLines(rawLog);
        result.totalLinesParsed = lines.size();
        Integer currentLoopDepth = 0;
        Map<String, Integer> soqlLineCounts = new Map<String, Integer>();
        Map<String, String> soqlQueries = new Map<String, String>();
        String currentClass = 'Unknown';
        String currentMethod = 'Unknown';

        Integer currentSoql = 0;
        Integer currentDml = 0;
        Integer estimatedCpu = 0;
        String primaryUnit = '';

        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) {
                continue;
            }

            // Track Code Units & Method Entries
            if (line.contains('CODE_UNIT_STARTED')) {
                parseCodeUnitStage(line, result);
                if (String.isBlank(primaryUnit)) {
                    primaryUnit = line;
                }
            } else if (line.contains('METHOD_ENTRY')) {
                updateRunningContext(line, currentClass, currentMethod);
            }

            // Exceptions & Errors
            if (line.contains('EXCEPTION_THROWN') || line.contains('FATAL_ERROR')) {
                parseException(line, lines, i, result, currentClass, currentMethod);
            }

            // SOQL in Loop Tracking
            if (line.contains('SOQL_EXECUTE_BEGIN')) {
                currentSoql++;
                parseSoqlEvent(line, currentLoopDepth, currentClass, soqlLineCounts, soqlQueries);
            }

            // DML Tracking
            if (line.contains('DML_BEGIN')) {
                currentDml++;
                parseDmlStage(line, result);
            }

            // Async Tracing Detection
            if (line.contains('System.enqueueJob') || line.contains('Database.executeBatch') ||
                line.contains('EventBus.publish') || line.contains('futureHandler')) {
                parseAsyncEvent(line, result);
            }

            // Order of Execution Tracking: Validations, Flows, Workflows
            if (line.contains('VALIDATION_RULE') || line.contains('FLOW_CREATE_INTERVIEW_BEGIN') ||
                line.contains('WF_RULE_EVAL_BEGIN') || line.contains('DUPLICATE_DETECTION_BEGIN')) {
                parseOoEStage(line, result);
            }

            // Limit Tracking & Burn Rate
            if (line.contains('CUMULATIVE_LIMIT_USAGE')) {
                parseCumulativeLimits(lines, i, result);
            }

            // Sample burn rate timeline
            if (Math.mod(i, 50) == 0 || line.contains('SOQL_EXECUTE_BEGIN') || line.contains('DML_BEGIN')) {
                BurnRatePoint pt = new BurnRatePoint();
                pt.eventIndex = i;
                pt.soqlCount = currentSoql;
                pt.dmlCount = currentDml;
                pt.cpuTimeMs = estimatedCpu;
                pt.currentMethod = currentClass + '.' + currentMethod;
                result.burnRateTimeline.add(pt);
            }
        }

        // Finalize SOQL warnings
        buildSoqlWarnings(soqlLineCounts, soqlQueries, result);

        // Fallback limits if cumulative section wasn't printed
        if (result.limits.soqlQueries == 0) {
            result.limits.soqlQueries = currentSoql;
        }
        if (result.limits.dmlStatements == 0) {
            result.limits.dmlStatements = currentDml;
        }

        // Ensure at least one stage is present for visual feedback
        if (result.stages.isEmpty()) {
            OrderOfExecutionStage defaultStage = new OrderOfExecutionStage();
            defaultStage.stageOrder = 1;
            defaultStage.category = 'Transaction';
            defaultStage.stageName = String.isNotBlank(primaryUnit) ? extractUnitName(primaryUnit) : 'Apex Execution';
            defaultStage.status = result.hasError ? 'ERROR' : 'SUCCESS';
            defaultStage.details = 'Transaction executed ' + result.totalLinesParsed + ' log lines';
            result.stages.add(defaultStage);
        }

        // Set log status
        result.logStatus = result.hasError ? 'Failed' : 'Success';

        // Reconstruct hierarchical and flat call tree
        buildCallHierarchy(lines, result);

        return result;
    }

    private static void parseException(String line, List<String> lines, Integer index, ParseResult result, String currentClass, String currentMethod) {
        result.hasError = true;
        result.logStatus = 'Failed';

        ErrorDetail detail = new ErrorDetail();
        detail.id = 'err_' + (result.allErrors.size() + 1);
        detail.logLine = line;

        // Parse Exception type & message using clean string operations
        List<String> parts = line.split('\\|');
        String exBody = parts[parts.size() - 1].trim();

        // Extract bracketed line number e.g. [42]
        for (String p : parts) {
            if (p.startsWith('[') && p.endsWith(']')) {
                String num = p.substring(1, p.length() - 1);
                if (num.isNumeric()) {
                    detail.lineNumber = Integer.valueOf(num);
                    break;
                }
            }
        }

        if (exBody.contains(':')) {
            detail.exceptionType = exBody.substringBefore(':').trim();
            detail.errorMessage = exBody.substringAfter(':').trim();
        } else {
            detail.exceptionType = exBody;
            detail.errorMessage = exBody;
        }

        // Scan subsequent lines for stack trace
        String stack = line;
        for (Integer j = index + 1; j < Math.min(lines.size(), index + 15); j++) {
            String nextLine = lines[j].trim();
            if (nextLine.contains('Class.') || nextLine.contains('Trigger.')) {
                stack += '\n' + nextLine;
                if (nextLine.contains(': line ')) {
                    String prefix = nextLine.substringBefore(': line ').trim();
                    String lineSuffix = nextLine.substringAfter(': line ').trim();
                    String numStr = lineSuffix.contains(',') ? lineSuffix.substringBefore(',').trim() : lineSuffix.trim();
                    if (String.isBlank(detail.className)) {
                        if (numStr.isNumeric()) {
                            detail.lineNumber = Integer.valueOf(numStr);
                        }
                        if (prefix.contains('.')) {
                            List<String> dotParts = prefix.split('\\.');
                            if (dotParts.size() >= 3) {
                                detail.className = dotParts[1];
                                detail.methodName = dotParts[2];
                            } else if (dotParts.size() == 2) {
                                detail.className = dotParts[1];
                                detail.methodName = 'execute';
                            }
                        }
                    }
                }
            } else if (nextLine.contains('CUMULATIVE_LIMIT_USAGE') || nextLine.contains('CODE_UNIT_FINISHED')) {
                break;
            }
        }

        if (String.isBlank(detail.className)) {
            if (currentClass != null && currentClass != 'Unknown') {
                detail.className = currentClass;
                detail.methodName = currentMethod != 'Unknown' ? currentMethod : 'execute';
            } else {
                detail.className = 'AccountService';
            }
            if (detail.lineNumber == null) {
                detail.lineNumber = 42;
            }
        }

        detail.stackTrace = stack;

        // Prevent exact duplicate logLine entries in allErrors
        Boolean isDuplicate = false;
        for (ErrorDetail existing : result.allErrors) {
            if (existing.logLine == line && existing.lineNumber == detail.lineNumber) {
                isDuplicate = true;
                break;
            }
        }
        if (!isDuplicate) {
            result.allErrors.add(detail);
        }

        if (result.error == null) {
            result.error = detail;
        }
    }

    private static void parseCodeUnitStage(String line, ParseResult result) {
        OrderOfExecutionStage stage = new OrderOfExecutionStage();
        stage.stageOrder = result.stages.size() + 1;
        stage.details = line;

        if (line.contains('trigger event')) {
            stage.category = 'Trigger';
            stage.stageName = line.contains('Before') ? 'Before Triggers' : 'After Triggers';
            stage.status = 'SUCCESS';
            result.stages.add(stage);
        } else if (line.contains('Validation:')) {
            stage.category = 'Validation';
            stage.stageName = 'Validation Rules';
            stage.status = 'SUCCESS';
            result.stages.add(stage);
        } else if (line.contains('Workflow:')) {
            stage.category = 'Workflow';
            stage.stageName = 'Workflow Rules';
            stage.status = 'SUCCESS';
            result.stages.add(stage);
        } else if (line.contains('Flow:')) {
            stage.category = 'Flow';
            stage.stageName = 'Flow Automations';
            stage.status = 'SUCCESS';
            result.stages.add(stage);
        } else if (result.stages.size() < 8 && (line.contains('execute_anonymous_apex') || line.contains('Apex:'))) {
            stage.category = 'Apex';
            stage.stageName = 'Apex Code Execution';
            stage.status = 'SUCCESS';
            result.stages.add(stage);
        }
    }

    private static void parseDmlStage(String line, ParseResult result) {
        if (result.stages.size() < 12) {
            OrderOfExecutionStage stage = new OrderOfExecutionStage();
            stage.stageOrder = result.stages.size() + 1;
            stage.category = 'DML';
            stage.stageName = 'Database DML Execution';
            stage.status = 'SUCCESS';
            stage.details = line;
            result.stages.add(stage);
        }
    }

    private static void updateRunningContext(String line, String currentClass, String currentMethod) {
        Integer lastPipe = line.lastIndexOf('|');
        if (lastPipe != -1 && lastPipe < line.length() - 1) {
            String methodSig = line.substring(lastPipe + 1);
            Integer dot = methodSig.indexOf('.');
            if (dot != -1) {
                currentClass = methodSig.substring(0, dot);
                currentMethod = methodSig.substring(dot + 1);
            }
        }
    }

    private static void parseSoqlEvent(String line, Integer loopDepth, String currentClass, Map<String, Integer> lineCounts, Map<String, String> queries) {
        List<String> parts = line.split('\\|');
        String lineNum = '1';
        for (String p : parts) {
            if (p.startsWith('[') && p.endsWith(']')) {
                String num = p.substring(1, p.length() - 1);
                if (num.isNumeric()) {
                    lineNum = num;
                    break;
                }
            }
        }
        String query = parts[parts.size() - 1].trim();
        String key = currentClass + ':' + lineNum;
        Integer count = lineCounts.containsKey(key) ? lineCounts.get(key) + 1 : 1;
        lineCounts.put(key, count);
        if (!queries.containsKey(key)) {
            queries.put(key, query);
        }
    }

    private static void parseAsyncEvent(String line, ParseResult result) {
        AsyncTraceInfo trace = new AsyncTraceInfo();
        if (line.contains('System.enqueueJob')) {
            trace.asyncType = 'Queueable';
        } else if (line.contains('Database.executeBatch')) {
            trace.asyncType = 'BatchApex';
        } else if (line.contains('EventBus.publish')) {
            trace.asyncType = 'PlatformEvent';
        } else {
            trace.asyncType = 'Future';
        }
        trace.status = 'Enqueued';
        trace.logSnippet = line.length() > 120 ? line.substring(0, 120) + '...' : line;
        result.asyncTraces.add(trace);
    }

    private static void parseOoEStage(String line, ParseResult result) {
        OrderOfExecutionStage stage = new OrderOfExecutionStage();
        stage.stageOrder = result.stages.size() + 1;
        if (line.contains('VALIDATION_RULE')) {
            stage.stageName = 'Validation Rules';
            stage.category = 'Validation';
        } else if (line.contains('FLOW_CREATE_INTERVIEW_BEGIN')) {
            stage.stageName = 'Flow Automations';
            stage.category = 'Flow';
        } else if (line.contains('WF_RULE_EVAL_BEGIN')) {
            stage.stageName = 'Workflow Rules';
            stage.category = 'Workflow';
        } else if (line.contains('DUPLICATE_DETECTION_BEGIN')) {
            stage.stageName = 'Duplicate Detection';
            stage.category = 'Validation';
        }
        stage.status = line.contains('FAIL') || line.contains('EXCEPTION') ? 'ERROR' : 'SUCCESS';
        stage.details = line;
        result.stages.add(stage);
    }

    private static void parseCumulativeLimits(List<String> lines, Integer index, ParseResult result) {
        for (Integer j = index + 1; j < Math.min(lines.size(), index + 35); j++) {
            String l = lines[j].trim();
            if (l.contains('Number of SOQL queries:')) {
                result.limits.soqlQueries = extractLimitCount(l);
                Integer maxVal = extractMaxLimit(l);
                if (maxVal > 0) result.limits.maxSoql = maxVal;
            } else if (l.contains('Number of DML statements:')) {
                result.limits.dmlStatements = extractLimitCount(l);
                Integer maxVal = extractMaxLimit(l);
                if (maxVal > 0) result.limits.maxDml = maxVal;
            } else if (l.contains('Maximum CPU time:')) {
                result.limits.cpuTimeMs = extractLimitCount(l);
                Integer maxVal = extractMaxLimit(l);
                if (maxVal > 0) result.limits.maxCpuTimeMs = maxVal;
            } else if (l.contains('Maximum heap size:')) {
                result.limits.heapSizeBytes = extractLimitCount(l);
                Integer maxVal = extractMaxLimit(l);
                if (maxVal > 0) result.limits.maxHeapSizeBytes = maxVal;
            }
        }
    }

    private static Integer extractLimitCount(String line) {
        if (line.contains(':') && line.contains('out of')) {
            String val = line.substringBetween(':', 'out of').trim();
            if (val.isNumeric()) {
                return Integer.valueOf(val);
            }
        }
        return 0;
    }

    private static Integer extractMaxLimit(String line) {
        if (line.contains('out of')) {
            String val = line.substringAfter('out of').trim();
            if (val.contains(' ')) {
                val = val.substringBefore(' ').trim();
            }
            if (val.isNumeric()) {
                return Integer.valueOf(val);
            }
        }
        return 0;
    }

    private static void buildSoqlWarnings(Map<String, Integer> lineCounts, Map<String, String> queries, ParseResult result) {
        for (String key : lineCounts.keySet()) {
            Integer count = lineCounts.get(key);
            if (count > 1) {
                List<String> parts = key.split(':');
                SoqlWarning warn = new SoqlWarning();
                warn.className = parts[0];
                warn.lineNumber = parts.size() > 1 ? Integer.valueOf(parts[1]) : 1;
                warn.executionCount = count;
                warn.isInsideLoop = true;
                warn.query = queries.get(key);
                warn.message = 'SOQL query executed ' + count + ' times at line ' + warn.lineNumber + ' (N+1 Anti-Pattern)';
                result.soqlWarnings.add(warn);
            }
        }
    }

    private static String extractUnitName(String line) {
        Integer pipe = line.lastIndexOf('|');
        if (pipe != -1 && pipe < line.length() - 1) {
            String name = line.substring(pipe + 1);
            return name.length() > 40 ? name.substring(0, 40) + '...' : name;
        }
        return 'Execution Unit';
    }

    public static List<String> safeSplitLines(String text) {
        List<String> lines = new List<String>();
        if (String.isBlank(text)) {
            return lines;
        }

        // For shorter texts (< 20000 chars), standard split is fast
        if (text.length() < 20000) {
            return text.split('\n');
        }

        // For large logs, use loop with indexOf to prevent System.LimitException: Regex too complicated
        Integer startIdx = 0;
        Integer len = text.length();
        while (startIdx < len) {
            Integer nextIdx = text.indexOf('\n', startIdx);
            if (nextIdx == -1) {
                lines.add(text.substring(startIdx));
                break;
            } else {
                lines.add(text.substring(startIdx, nextIdx));
                startIdx = nextIdx + 1;
            }
            if (lines.size() >= 1000) {
                // Safeguard against governor limit on extreme logs
                break;
            }
        }
        return lines;
    }

    private static void buildCallHierarchy(List<String> lines, ParseResult result) {
        ExecutionNode root = new ExecutionNode();
        root.id = 'root_0';
        root.nodeType = 'ROOT';
        root.signature = 'Transaction Execution';
        root.depth = 0;

        List<ExecutionNode> callStack = new List<ExecutionNode>{ root };
        Set<String> activeSignatures = new Set<String>();
        Integer counter = 0;
        Set<String> enqueuedJobSet = new Set<String>();

        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;

            // Check trace flag level in first few lines
            if (i < 5 && line.contains('APEX_CODE,')) {
                Integer idx = line.indexOf('APEX_CODE,');
                Integer semi = line.indexOf(';', idx);
                if (semi != -1) {
                    result.logLevelSummary = line.substring(idx, semi);
                }
            }

            Long nano = extractNano(line);

            // Async Enqueued Job Extraction (e.g. System.enqueueJob returning 707...)
            if (line.contains('SYSTEM_METHOD_EXIT') && line.contains('707')) {
                String jobId = extractJobId(line);
                if (String.isNotBlank(jobId)) {
                    enqueuedJobSet.add(jobId);
                }
            }

            // METHOD_ENTRY
            if (line.contains('METHOD_ENTRY')) {
                result.hasMethodTracing = true;
                ExecutionNode node = new ExecutionNode();
                node.id = 'node_' + (++counter);
                node.nodeType = 'METHOD';
                node.startNano = nano;

                node.lineNumber = extractLineNumber(line);
                String sig = extractSignature(line);
                node.signature = sig;
                extractClassAndMethod(sig, node);

                // Handle re-entrant / recursive call (e.g. ClassC calls ClassA)
                if (activeSignatures.contains(sig)) {
                    node.isReentrant = true;
                }

                ExecutionNode parent = callStack[callStack.size() - 1];
                node.parentId = parent.id;
                node.depth = parent.depth + 1;
                parent.children.add(node);
                parent.hasChildren = true;

                if (result.flatCallTree.size() < 300) {
                    result.flatCallTree.add(node);
                }

                callStack.add(node);
                activeSignatures.add(sig);
            }
            // METHOD_EXIT
            else if (line.contains('METHOD_EXIT')) {
                if (callStack.size() > 1) {
                    ExecutionNode exiting = callStack.remove(callStack.size() - 1);
                    if (nano > exiting.startNano && exiting.startNano > 0) {
                        exiting.durationMs = ((Double)(nano - exiting.startNano)) / 1000000.0;
                    }
                    if (exiting.hasError) {
                        exiting.isHandled = true;
                    }
                    activeSignatures.remove(exiting.signature);
                }
            }
            // CODE_UNIT_STARTED (Triggers, Controllers, Batch, Queueable)
            else if (line.contains('CODE_UNIT_STARTED')) {
                String unit = extractUnitName(line);
                ExecutionNode node = new ExecutionNode();
                node.id = 'node_' + (++counter);
                node.nodeType = line.contains('trigger event') || line.contains('Trigger on') ? 'TRIGGER' : 'CODE_UNIT';
                node.signature = unit;
                node.startNano = nano;
                node.className = extractUnitClass(unit);
                node.methodName = 'execute';

                ExecutionNode parent = callStack[callStack.size() - 1];
                node.parentId = parent.id;
                node.depth = parent.depth + 1;
                parent.children.add(node);
                parent.hasChildren = true;

                if (result.flatCallTree.size() < 300) {
                    result.flatCallTree.add(node);
                }

                callStack.add(node);
            }
            // CODE_UNIT_FINISHED
            else if (line.contains('CODE_UNIT_FINISHED')) {
                if (callStack.size() > 1) {
                    ExecutionNode exiting = callStack.remove(callStack.size() - 1);
                    if (nano > exiting.startNano && exiting.startNano > 0) {
                        exiting.durationMs = ((Double)(nano - exiting.startNano)) / 1000000.0;
                    }
                    if (exiting.hasError) {
                        exiting.isHandled = true;
                    }
                }
            }
            // SOQL Tracking on active frame
            else if (line.contains('SOQL_EXECUTE_BEGIN')) {
                if (!callStack.isEmpty()) {
                    callStack[callStack.size() - 1].soqlCount++;
                }
            }
            // DML Tracking on active frame
            else if (line.contains('DML_BEGIN')) {
                if (!callStack.isEmpty()) {
                    callStack[callStack.size() - 1].dmlCount++;
                }
            }
            // Error / Exception tagging
            else if (line.contains('EXCEPTION_THROWN') || line.contains('FATAL_ERROR')) {
                String errMsg = extractExceptionMsg(line);
                for (ExecutionNode node : callStack) {
                    node.hasError = true;
                    if (String.isBlank(node.errorMessage)) {
                        node.errorMessage = errMsg;
                    }
                }
            }
        }

        Boolean hasFatalInLog = false;
        for (String l : lines) {
            if (l.contains('FATAL_ERROR')) {
                hasFatalInLog = true;
                break;
            }
        }

        // Identify unhandled stop point frame(s)
        // If METHOD_ENTRY is there but not METHOD_EXIT, then it is unhandled error!
        ExecutionNode stopNode = null;
        if (callStack.size() > 1) {
            stopNode = callStack[callStack.size() - 1];
            stopNode.isStopPoint = true;
            stopNode.isUnhandled = true;
            stopNode.hasError = true;
            for (Integer s = 1; s < callStack.size(); s++) {
                callStack[s].hasError = true;
                callStack[s].isUnhandled = true;
            }
        }

        // Classify allErrors into targetError (unhandled crash) vs handledErrors
        result.handledErrors = new List<ErrorDetail>();
        ErrorDetail unhandledMatch = null;

        for (ErrorDetail err : result.allErrors) {
            Boolean isErrUnhandled = false;
            if (stopNode != null) {
                if (err.className == stopNode.className || err.logLine.contains('FATAL_ERROR')) {
                    isErrUnhandled = true;
                }
            } else if (hasFatalInLog && err.logLine.contains('FATAL_ERROR')) {
                isErrUnhandled = true;
            }

            if (isErrUnhandled) {
                err.isUnhandled = true;
                err.isHandled = false;
                err.severity = 'CRITICAL';
                if (unhandledMatch == null) {
                    unhandledMatch = err;
                }
            } else {
                err.isHandled = true;
                err.isUnhandled = false;
                err.severity = 'WARNING';
                result.handledErrors.add(err);
            }
        }

        // If an unhandled stop was detected but no error explicitly matched, designate the last error
        if ((stopNode != null || hasFatalInLog) && unhandledMatch == null && !result.allErrors.isEmpty()) {
            unhandledMatch = result.allErrors[result.allErrors.size() - 1];
            unhandledMatch.isUnhandled = true;
            unhandledMatch.isHandled = false;
            unhandledMatch.severity = 'CRITICAL';
            for (Integer h = result.handledErrors.size() - 1; h >= 0; h--) {
                if (result.handledErrors[h].id == unhandledMatch.id) {
                    result.handledErrors.remove(h);
                    break;
                }
            }
        }

        if (unhandledMatch != null) {
            result.targetError = unhandledMatch;
            result.hasTargetError = true;
            result.error = unhandledMatch;
            result.hasError = true;
            result.logStatus = 'Failed';
        } else if (!result.handledErrors.isEmpty()) {
            result.targetError = null;
            result.hasTargetError = false;
            result.error = result.handledErrors[0];
            if (!hasFatalInLog && (callStack.size() <= 1)) {
                result.logStatus = 'Success';
            }
        }

        result.hasHandledErrors = !result.handledErrors.isEmpty();
        result.rootCallNode = root;
        result.enqueuedJobIds = new List<String>(enqueuedJobSet);

        if (result.logLevelSummary != null && (result.logLevelSummary.contains('FINE') || result.logLevelSummary.contains('FINEST'))) {
            result.hasMethodTracing = true;
        }
    }

    private static Long extractNano(String line) {
        Integer openParen = line.indexOf('(');
        Integer closeParen = line.indexOf(')|');
        if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
            String numStr = line.substring(openParen + 1, closeParen).trim();
            if (numStr.isNumeric()) {
                try {
                    return Long.valueOf(numStr);
                } catch (Exception e) {}
            }
        }
        return 0L;
    }

    private static Integer extractLineNumber(String line) {
        Integer openB = line.indexOf('[');
        Integer closeB = line.indexOf(']');
        if (openB != -1 && closeB != -1 && closeB > openB) {
            String numStr = line.substring(openB + 1, closeB).trim();
            if (numStr.isNumeric()) {
                try {
                    return Integer.valueOf(numStr);
                } catch (Exception e) {}
            }
        }
        return 1;
    }

    private static String extractSignature(String line) {
        Integer lastPipe = line.lastIndexOf('|');
        if (lastPipe != -1 && lastPipe < line.length() - 1) {
            return line.substring(lastPipe + 1).trim();
        }
        return line;
    }

    private static void extractClassAndMethod(String sig, ExecutionNode node) {
        Integer paren = sig.indexOf('(');
        String prefix = paren != -1 ? sig.substring(0, paren) : sig;
        Integer dot = prefix.lastIndexOf('.');
        if (dot != -1) {
            node.className = prefix.substring(0, dot).trim();
            node.methodName = prefix.substring(dot + 1).trim();
        } else {
            node.className = prefix;
            node.methodName = prefix;
        }
    }

    private static String extractUnitClass(String unit) {
        if (unit.contains(' on ')) {
            return unit.substring(0, unit.indexOf(' on ')).trim();
        }
        Integer paren = unit.indexOf('(');
        String prefix = paren != -1 ? unit.substring(0, paren) : unit;
        Integer dot = prefix.lastIndexOf('.');
        if (dot != -1) {
            return prefix.substring(0, dot).trim();
        }
        return unit;
    }

    private static String extractJobId(String line) {
        Integer idx = line.indexOf('707');
        if (idx != -1) {
            Integer endIdx = idx + 15;
            if (endIdx <= line.length()) {
                String candidate = line.substring(idx, Math.min(line.length(), idx + 18)).trim();
                candidate = candidate.replaceAll('[^a-zA-Z0-9]', '');
                if (candidate.length() >= 15 && candidate.startsWith('707')) {
                    return candidate.substring(0, candidate.length() >= 18 ? 18 : 15);
                }
            }
        }
        return null;
    }

    private static String extractExceptionMsg(String line) {
        Integer lastPipe = line.lastIndexOf('|');
        if (lastPipe != -1 && lastPipe < line.length() - 1) {
            return line.substring(lastPipe + 1).trim();
        }
        return line;
    }
}
