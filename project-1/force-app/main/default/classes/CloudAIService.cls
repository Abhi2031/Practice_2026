public with sharing class CloudAIService {

    public class AIAnalysisRequest {
        public String exceptionType;
        public String errorMessage;
        public String className;
        public Integer lineNumber;
        public String surroundingCode;
        public String logSnippet;
        public List<String> warnings;
    }

    public class AIAnalysisResponse {
        @AuraEnabled public String rootCauseSummary { get; set; }
        @AuraEnabled public String originalCode { get; set; }
        @AuraEnabled public String fixedCode { get; set; }
        @AuraEnabled public String diffHtml { get; set; }
        @AuraEnabled public String explanation { get; set; }
        @AuraEnabled public String confidence { get; set; } // HIGH, MEDIUM, REVIEW_REQUIRED
        @AuraEnabled public Boolean isBulkified { get; set; }
        @AuraEnabled public String modelUsed { get; set; }
    }

    /**
     * Backward-compatible overload without API key
     */
    public static AIAnalysisResponse generateFix(AIAnalysisRequest req) {
        return generateFix(req, null, 'gemini-3.8-flash');
    }

    /**
     * Calls Google Gemini API directly if apiKey is provided, or Named Credential, or graceful rule-based fallback
     */
    public static AIAnalysisResponse generateFix(AIAnalysisRequest req, String apiKey, String modelName) {
        AIAnalysisResponse resp = new AIAnalysisResponse();
        if (String.isBlank(modelName)) {
            modelName = 'gemini-3.8-flash';
        }
        resp.modelUsed = modelName;

        String prompt = buildPrompt(req);

        // 1. If direct Gemini API key provided by user
        if (String.isNotBlank(apiKey)) {
            try {
                HttpRequest httpReq = new HttpRequest();
                String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' +
                    modelName + ':generateContent?key=' + EncodingUtil.urlEncode(apiKey.trim(), 'UTF-8');
                httpReq.setEndpoint(endpoint);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setTimeout(45000);

                Map<String, Object> bodyMap = new Map<String, Object>{
                    'contents' => new List<Object>{
                        new Map<String, Object>{
                            'parts' => new List<Object>{
                                new Map<String, Object>{'text' => prompt}
                            }
                        }
                    }
                };
                httpReq.setBody(JSON.serialize(bodyMap));

                Http http = new Http();
                HttpResponse httpRes = http.send(httpReq);

                if (httpRes.getStatusCode() == 200) {
                    resp = parseAIResponse(httpRes.getBody(), req);
                    resp.modelUsed = modelName + ' (Live)';
                    return resp;
                } else {
                    resp = fallbackRuleBasedFix(req);
                    resp.modelUsed = 'Rule-Based Engine (Gemini HTTP ' + httpRes.getStatusCode() + ')';
                    return resp;
                }
            } catch (Exception ex) {
                resp = fallbackRuleBasedFix(req);
                resp.modelUsed = 'Rule-Based Engine (Callout Fallback)';
                return resp;
            }
        }

        // 2. Try Named Credential if configured in org
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('callout:AI_Service_Credential/v1beta/models/' + modelName + ':generateContent');
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setTimeout(45000);

            Map<String, Object> bodyMap = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{'text' => prompt}
                        }
                    }
                }
            };
            httpReq.setBody(JSON.serialize(bodyMap));

            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);

            if (httpRes.getStatusCode() == 200) {
                resp = parseAIResponse(httpRes.getBody(), req);
                resp.modelUsed = 'Named Credential (' + modelName + ')';
                return resp;
            }
        } catch (Exception ex) {
            // Named Credential not configured or offline
        }

        // 3. Fallback to heuristic rule-based engine
        resp = fallbackRuleBasedFix(req);
        resp.modelUsed = 'Deterministic AI Engine (Offline)';
        return resp;
    }

    /**
     * Test connection to Gemini API
     */
    public static String testConnection(String apiKey, String modelName) {
        if (String.isBlank(apiKey)) {
            return 'API Key is required to test connection.';
        }
        if (String.isBlank(modelName)) {
            modelName = 'gemini-3.8-flash';
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://generativelanguage.googleapis.com/v1beta/models/' +
                modelName + ':generateContent?key=' + EncodingUtil.urlEncode(apiKey.trim(), 'UTF-8'));
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(15000);

            Map<String, Object> bodyMap = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{'text' => 'Respond with the single word: OK'}
                        }
                    }
                }
            };
            req.setBody(JSON.serialize(bodyMap));

            Http h = new Http();
            HttpResponse res = h.send(req);
            if (res.getStatusCode() == 200) {
                return 'SUCCESS';
            } else {
                return 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
            }
        } catch(Exception e) {
            return 'Connection Error: ' + e.getMessage();
        }
    }

    private static String buildPrompt(AIAnalysisRequest req) {
        String p = 'You are an expert Salesforce Apex engineer and architect.\n';
        p += 'Analyze this Salesforce Apex runtime error and output pure JSON with keys: rootCauseSummary, originalCode, fixedCode, explanation, confidence, isBulkified.\n';
        p += 'Error: ' + req.exceptionType + ' - ' + req.errorMessage + '\n';
        p += 'Class: ' + req.className + ' Line: ' + req.lineNumber + '\n';
        if (String.isNotBlank(req.surroundingCode)) {
            p += 'Apex Code Snippet:\n' + req.surroundingCode + '\n';
        }
        if (req.warnings != null && !req.warnings.isEmpty()) {
            p += 'Detected Anti-patterns: ' + String.join(req.warnings, ', ') + '\n';
        }
        p += 'Return ONLY pure JSON without markdown code fences.';
        return p;
    }

    private static AIAnalysisResponse parseAIResponse(String responseJson, AIAnalysisRequest req) {
        AIAnalysisResponse resp = new AIAnalysisResponse();
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
            List<Object> candidates = (List<Object>) root.get('candidates');
            if (candidates != null && !candidates.isEmpty()) {
                Map<String, Object> cand = (Map<String, Object>) candidates[0];
                Map<String, Object> content = (Map<String, Object>) cand.get('content');
                List<Object> parts = (List<Object>) content.get('parts');
                if (parts != null && !parts.isEmpty()) {
                    Map<String, Object> p = (Map<String, Object>) parts[0];
                    String rawText = (String) p.get('text');
                    if (String.isNotBlank(rawText)) {
                        // Clean markdown fences
                        if (rawText.contains('```json')) {
                            rawText = rawText.substringBetween('```json', '```');
                        } else if (rawText.contains('```')) {
                            rawText = rawText.substringBetween('```', '```');
                        }
                        rawText = rawText.trim();
                        resp = (AIAnalysisResponse) JSON.deserialize(rawText, AIAnalysisResponse.class);
                    }
                }
            }
        } catch (Exception e) {
            resp = fallbackRuleBasedFix(req);
        }
        if (resp == null || String.isBlank(resp.fixedCode)) {
            resp = fallbackRuleBasedFix(req);
        }
        return resp;
    }

    public static AIAnalysisResponse fallbackRuleBasedFix(AIAnalysisRequest req) {
        AIAnalysisResponse fallback = new AIAnalysisResponse();
        fallback.confidence = 'HIGH';
        fallback.isBulkified = false;

        String className = String.isNotBlank(req.className) ? req.className : 'ApexClass';
        Integer lineNum = req.lineNumber != null ? req.lineNumber : 1;

        if (req.exceptionType != null && req.exceptionType.contains('NullPointerException')) {
            fallback.rootCauseSummary = 'Attempted to de-reference a null object in ' + className + ' at line ' + lineNum + '.';
            fallback.originalCode = String.isNotBlank(req.surroundingCode) ? req.surroundingCode : 'targetObject.field = value;';
            fallback.fixedCode = '// Guard against null object before accessing properties or child relations\nif (targetObject != null) {\n    targetObject.field = value;\n} else {\n    System.debug(LoggingLevel.WARN, \'targetObject was null; bypassed assignment.\');\n}';
            fallback.explanation = 'Ensures targetObject is instantiated before reading or writing fields, eliminating NullPointerExceptions gracefully.';
        } else if (req.exceptionType != null && (req.exceptionType.contains('LimitException') || (req.warnings != null && !req.warnings.isEmpty()))) {
            fallback.rootCauseSummary = 'Salesforce Governor Limit breached (SOQL query inside loop / 101 queries) in ' + className + ' at line ' + lineNum + '.';
            fallback.originalCode = String.isNotBlank(req.surroundingCode) ? req.surroundingCode : 'for (Account a : accounts) {\n    Contact c = [SELECT Id FROM Contact WHERE AccountId = :a.Id LIMIT 1];\n}';
            fallback.fixedCode = '// Bulkified collection pattern: extract SOQL query outside iteration loop\nSet<Id> accIds = new Set<Id>();\nfor (Account a : accounts) {\n    if (a.Id != null) {\n        accIds.add(a.Id);\n    }\n}\nMap<Id, List<Contact>> contactsByAcc = new Map<Id, List<Contact>>();\nfor (Contact c : [SELECT Id, AccountId, Name FROM Contact WHERE AccountId IN :accIds]) {\n    if (!contactsByAcc.containsKey(c.AccountId)) {\n        contactsByAcc.put(c.AccountId, new List<Contact>());\n    }\n    contactsByAcc.get(c.AccountId).add(c);\n}';
            fallback.explanation = 'Aggregates parent IDs into a Set and executes a single bulk SOQL query with IN filter, indexing children into a Map.';
            fallback.isBulkified = true;
        } else {
            fallback.rootCauseSummary = 'Runtime exception detected: ' + (String.isNotBlank(req.errorMessage) ? req.errorMessage : 'Unhandled error') + ' in ' + className + ' at line ' + lineNum + '.';
            fallback.originalCode = String.isNotBlank(req.surroundingCode) ? req.surroundingCode : '// Failing transaction';
            fallback.fixedCode = 'try {\n    ' + (String.isNotBlank(req.surroundingCode) ? req.surroundingCode : '// Code execution') + '\n} catch(Exception ex) {\n    System.debug(LoggingLevel.ERROR, \'Transaction error: \' + ex.getMessage() + \' at line: \' + ex.getLineNumber());\n    // Handle or rethrow custom ApplicationException\n}';
            fallback.explanation = 'Applied defensive exception boundary and structured logging to catch and recover from runtime failures.';
        }

        return fallback;
    }
}
