@isTest
private class LogParserServiceTest {

    @isTest
    static void testParseSampleLog() {
        String sample = LogAnalyzerController.getSampleErrorLog();
        Test.startTest();
        LogParserService.ParseResult result = LogParserService.parseLog(sample);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.hasError, 'Should detect NullPointerException');
        System.assertNotEquals(null, result.error, 'Error object should be populated');
        System.assertEquals('AccountService', result.error.className, 'Class should match AccountService');
        System.assertEquals(42, result.error.lineNumber, 'Line number should match 42');
        System.assertEquals(12, result.limits.soqlQueries, 'Should parse 12 SOQL queries');
    }

    @isTest
    static void testAIFallbackFix() {
        CloudAIService.AIAnalysisRequest req = new CloudAIService.AIAnalysisRequest();
        req.exceptionType = 'System.NullPointerException';
        req.errorMessage = 'Attempt to de-reference a null object';
        req.className = 'AccountService';
        req.lineNumber = 42;
        req.surroundingCode = 'Account acc = null;\nString name = acc.Name;';

        Test.startTest();
        CloudAIService.AIAnalysisResponse resp = CloudAIService.generateFix(req);
        CloudAIService.AIAnalysisResponse respWithConfig = CloudAIService.generateFix(req, 'mock_key', 'gemini-2.5-flash');
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response should not be null');
        System.assertNotEquals(null, resp.fixedCode, 'Fixed code should be generated');
        System.assert(resp.fixedCode.contains('null'), 'Fixed code should guard against null pointer');
        System.assertNotEquals(null, respWithConfig, 'Configured response should not be null');
    }

    @isTest
    static void testControllerMethods() {
        Test.startTest();
        List<LogAnalyzerController.LogOption> logs = LogAnalyzerController.getRecentLogs();
        LogParserService.ParseResult rawResult = LogAnalyzerController.analyzeRawLog(LogAnalyzerController.getSampleErrorLog());
        
        CloudAIService.AIAnalysisResponse fix = LogAnalyzerController.requestAIFix(
            'System.LimitException',
            'Too many SOQL queries: 101',
            'AccountService',
            24,
            'for(Account a : accs) { Contact c = [SELECT Id FROM Contact]; }',
            new List<String>{'SOQL in loop'}
        );

        CloudAIService.AIAnalysisResponse fixWithConfig = LogAnalyzerController.requestAIFixWithConfig(
            'System.LimitException',
            'Too many SOQL queries: 101',
            'AccountService',
            24,
            'for(Account a : accs) { Contact c = [SELECT Id FROM Contact]; }',
            new List<String>{'SOQL in loop'},
            'test_key',
            'gemini-2.5-flash'
        );

        String testConn = LogAnalyzerController.testGeminiConnection('mock_key', 'gemini-2.5-flash');
        LogAnalyzerController.MultiLogResult multi = LogAnalyzerController.analyzeUserRecentLogs(null, 5);

        Test.stopTest();

        System.assertNotEquals(null, logs);
        System.assertNotEquals(null, rawResult);
        System.assertNotEquals(null, fix);
        System.assertNotEquals(null, fixWithConfig);
        System.assertNotEquals(null, testConn);
        System.assertNotEquals(null, multi);
        System.assertNotEquals(null, multi.transactionGroups);
        System.assertNotEquals(null, multi.chronologicalLogs);
        System.assertNotEquals(null, multi.unrelatedLogs);
    }

    @isTest
    static void testDeepRecursiveCallTreeAndCausalJobs() {
        String logText = '59.0 APEX_CODE,FINEST;APEX_PROFILING,INFO\n' +
            '10:15:20.001 (1000000)|EXECUTION_STARTED\n' +
            '10:15:20.002 (2000000)|CODE_UNIT_STARTED|[EXTERNAL]|01q5g0000001234|AccountTrigger on Account trigger event BeforeInsert\n' +
            '10:15:20.010 (10000000)|METHOD_ENTRY|[10]|01p5g0000001111|ClassA.methodA()\n' +
            '10:15:20.015 (15000000)|METHOD_ENTRY|[20]|01p5g0000002222|ClassB.methodB()\n' +
            '10:15:20.020 (20000000)|METHOD_ENTRY|[30]|01p5g0000003333|ClassC.methodC()\n' +
            '10:15:20.025 (25000000)|METHOD_ENTRY|[10]|01p5g0000001111|ClassA.methodA()\n' +
            '10:15:20.030 (30000000)|SYSTEM_METHOD_ENTRY|[35]|System.enqueueJob(Object)\n' +
            '10:15:20.035 (35000000)|SYSTEM_METHOD_EXIT|[35]|7075g0000012345\n' +
            '10:15:20.040 (40000000)|METHOD_EXIT|[10]|01p5g0000001111|ClassA.methodA()\n' +
            '10:15:20.045 (45000000)|METHOD_EXIT|[30]|01p5g0000003333|ClassC.methodC()\n' +
            '10:15:20.050 (50000000)|METHOD_EXIT|[20]|01p5g0000002222|ClassB.methodB()\n' +
            '10:15:20.055 (55000000)|METHOD_EXIT|[10]|01p5g0000001111|ClassA.methodA()\n' +
            '10:15:20.060 (60000000)|CODE_UNIT_FINISHED|AccountTrigger on Account trigger event BeforeInsert\n' +
            '10:15:20.070 (70000000)|EXECUTION_FINISHED';

        Test.startTest();
        LogParserService.ParseResult result = LogParserService.parseLog(logText);
        Test.stopTest();

        System.assertNotEquals(null, result.rootCallNode, 'Root node should not be null');
        System.assertEquals(true, result.hasMethodTracing, 'Should have method tracing enabled');
        System.assert(result.flatCallTree.size() >= 4, 'Should have parsed call tree nodes');
        System.assert(result.enqueuedJobIds.contains('7075g0000012345'), 'Should have extracted 707 job ID');

        Boolean foundReentrant = false;
        for (LogParserService.ExecutionNode node : result.flatCallTree) {
            if (node.isReentrant) {
                foundReentrant = true;
                break;
            }
        }
        System.assertEquals(true, foundReentrant, 'Should identify re-entrant call to ClassA.methodA');
    }

    @isTest
    static void testHandledVsUnhandledErrors() {
        // Log containing a handled error in MethodA (it exits normally) followed by unhandled error in MethodB (no exit)
        String logText = '59.0 APEX_CODE,FINEST;APEX_PROFILING,INFO\n' +
            '11:00:00.001 (1000000)|EXECUTION_STARTED\n' +
            '11:00:00.002 (2000000)|CODE_UNIT_STARTED|[EXTERNAL]|Controller.init()\n' +
            '11:00:00.010 (10000000)|METHOD_ENTRY|[15]|01p1|ServiceA.safeOperation()\n' +
            '11:00:00.012 (12000000)|EXCEPTION_THROWN|[18]|System.QueryException: List has no rows for assignment to SObject\n' +
            'Class.ServiceA.safeOperation: line 18, column 1\n' +
            '11:00:00.015 (15000000)|METHOD_EXIT|[15]|01p1|ServiceA.safeOperation()\n' +
            '11:00:00.020 (20000000)|METHOD_ENTRY|[40]|01p2|ServiceB.crashOperation()\n' +
            '11:00:00.025 (25000000)|EXCEPTION_THROWN|[42]|System.NullPointerException: Attempt to de-reference a null object\n' +
            'Class.ServiceB.crashOperation: line 42, column 1\n' +
            '11:00:00.030 (30000000)|FATAL_ERROR|System.NullPointerException: Attempt to de-reference a null object\n' +
            '11:00:00.035 (35000000)|EXECUTION_FINISHED';

        Test.startTest();
        LogParserService.ParseResult result = LogParserService.parseLog(logText);
        Test.stopTest();

        System.assertEquals(true, result.hasError, 'Should report error');
        System.assertEquals('Failed', result.logStatus, 'Status should be Failed');
        System.assertNotEquals(null, result.targetError, 'Target error should be identified');
        System.assertEquals(true, result.targetError.isUnhandled, 'Target error should be unhandled');
        System.assertEquals(true, result.hasHandledErrors, 'Should have handled error from safeOperation');
        System.assertEquals(1, result.handledErrors.size(), 'Should have 1 handled error');
        System.assertEquals(true, result.handledErrors[0].isHandled, 'First error should be marked as handled');

        // Verify stop point in call tree
        Boolean foundStopPoint = false;
        for (LogParserService.ExecutionNode node : result.flatCallTree) {
            if (node.isStopPoint) {
                foundStopPoint = true;
                System.assertEquals('ServiceB', node.className, 'Stop point should be ServiceB');
                System.assertEquals('crashOperation', node.methodName, 'Stop point method should be crashOperation');
            }
        }
        System.assertEquals(true, foundStopPoint, 'Should have marked ServiceB.crashOperation as stop point');
    }
}
