# Sonar way (Java) code-quality snapshot

- Profile: `Sonar way`
- Profile key: `AZvf8pNwYhj-UqYS_Z5n`
- Language: `java`
- Rules updated at: `2026-03-16T14:10:41+0000`
- Exported at (UTC): `2026-03-17T14:53:44Z`
- Active rules: `586`

## How To Use This Snapshot
- Read this file first.
- Use the diagram as the behavioral source of truth.
- Use `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
- If a quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the rule through naming, structure, safety, and maintainability choices.

## Concern Counts
- Reliability: `177`
- Security: `66`
- Maintainability: `326`
- Security hotspots: `32`

## Severity Counts
- BLOCKER: `46`
- CRITICAL: `111`
- MAJOR: `270`
- MINOR: `151`
- INFO: `8`
- UNKNOWN: `0`

## Highest-Severity Rules
- `java:S1190`: Future keywords should not be used as names
- `java:S1219`: "switch" statements should not contain non-case labels
- `java:S128`: Switch cases should end with an unconditional "break" statement
- `java:S1845`: Methods and field names should not be the same or differ only by capitalization
- `java:S2095`: Resources should be closed
- `java:S2115`: A secure password should be used when connecting to a database
- `java:S2168`: Double-checked locking should not be used
- `java:S2178`: Short-circuit logic should be used in boolean contexts
- `java:S2187`: TestCases should contain tests
- `java:S2188`: JUnit test cases should call super methods
- `java:S2189`: Loops should not be infinite
- `java:S2229`: Methods should not call same-class methods with incompatible "@Transactional" values

## Parameterized Rules
- `java:S100`: Method names should comply with a naming convention (format=^[a-z][a-zA-Z0-9]*$)
- `java:S101`: Class names should comply with a naming convention (format=^[A-Z][a-zA-Z0-9]*$)
- `java:S107`: Methods should not have too many parameters (constructorMax=7, max=7)
- `java:S110`: Inheritance tree of classes should not be too deep (max=5)
- `java:S114`: Interface names should comply with a naming convention (format=^[A-Z][a-zA-Z0-9]*$)
- `java:S115`: Constant names should comply with a naming convention (format=^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$)
- `java:S116`: Field names should comply with a naming convention (format=^[a-z][a-zA-Z0-9]*$)
- `java:S117`: Local variable and method parameter names should comply with a naming convention (format=^[a-z][a-zA-Z0-9]*$)
- `java:S119`: Type parameter names should comply with a naming convention (format=^[A-Z][0-9]?$)
- `java:S1192`: String literals should not be duplicated (threshold=3)
- `java:S120`: Package names should comply with a naming convention (format=^[a-z_]+(\.[a-z_][a-z0-9_]*)*$)
- `java:S1479`: "switch" statements should not have too many "case" clauses (maximum=30)
- `java:S2068`: Credentials should not be hard-coded (credentialWords=password,passwd,pwd,passphrase,java.naming.security.credentials)
- `java:S2187`: TestCases should contain tests (TestClassNamePattern=.*(Test|Tests|TestCase))
- `java:S2479`: Whitespace and control characters in literals should be explicit (allowTabsInTextBlocks=false)
- `java:S3008`: Static non-final field names should comply with a naming convention (format=^[a-z][a-zA-Z0-9]*$)
- `java:S3577`: Test classes should comply with a naming convention (format=^((Test|IT)[a-zA-Z0-9_]+|[A-Z][a-zA-Z0-9_]*(Test|Tests|TestCase|IT|ITCase))$)
- `java:S3776`: Cognitive Complexity of methods should not be too high (Threshold=15)
- `java:S5693`: Allowing requests with excessive content length is security-sensitive (fileUploadSizeLimit=8388608)
- `java:S5843`: Regular expressions should not be too complicated (maxComplexity=20)
- `java:S5961`: Test methods should not contain too many assertions (MaximumAssertionNumber=25)
- `java:S5998`: Regular expressions should not overflow the stack (maxStackConsumptionFactor=5.0)
- `java:S6203`: Text blocks should not be used in complex expressions (MaximumNumberOfLines=5)
- `java:S6418`: Secrets should not be hard-coded (randomnessSensibility=5.0, secretWords=api[_.-]?key,auth,credential,secret,token)
- `java:S6539`: Classes should not depend on an excessive number of classes (aka Monster Class) (couplingThreshold=20)
- `java:S6541`: Methods should not perform too many tasks (aka Brain method) (cyclomaticThreshold=15, locThreshold=65, nestingThreshold=3, nodvThreshold=7)
- `java:S8444`: Excessive logic before super() should not bloat constructor (statementsThreshold=5)

## Partial Metadata Rules
- The following rules were present in the profile backup XML but missing from the bulk Web API export, so their lock-file records are partial:
- `java:S6263`
- `java:S6863`
- `java:S7183`
- `java:S7481`
- `javaarchitecture:S7788`
