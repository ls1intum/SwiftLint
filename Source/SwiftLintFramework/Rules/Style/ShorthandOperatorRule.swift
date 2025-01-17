import SwiftSyntax

public struct ShorthandOperatorRule: ConfigurationProviderRule, SourceKitFreeRule {
    public var configuration = SeverityConfiguration(.error)

    public init() {}

    public static let description = RuleDescription(
        identifier: "shorthand_operator",
        name: "Shorthand Operator",
        description: "Prefer shorthand operators (+=, -=, *=, /=) over doing the operation and assigning.",
        kind: .style,
        nonTriggeringExamples: allOperators.flatMap { operation in
            [
                Example("foo \(operation)= 1"),
                Example("foo \(operation)= variable"),
                Example("foo \(operation)= bar.method()"),
                Example("self.foo = foo \(operation) 1"),
                Example("foo = self.foo \(operation) 1"),
                Example("page = ceilf(currentOffset \(operation) pageWidth)"),
                Example("foo = aMethod(foo \(operation) bar)"),
                Example("foo = aMethod(bar \(operation) foo)")
            ]
        } + [
            Example("var helloWorld = \"world!\"\n helloWorld = \"Hello, \" + helloWorld"),
            Example("angle = someCheck ? angle : -angle"),
            Example("seconds = seconds * 60 + value")
        ],
        triggeringExamples: allOperators.flatMap { operation in
            [
                Example("↓foo = foo \(operation) 1\n"),
                Example("↓foo = foo \(operation) aVariable\n"),
                Example("↓foo = foo \(operation) bar.method()\n"),
                Example("↓foo.aProperty = foo.aProperty \(operation) 1\n"),
                Example("↓self.aProperty = self.aProperty \(operation) 1\n")
            ]
        } + [
            Example("↓n = n + i / outputLength"),
            Example("↓n = n - i / outputLength")
        ]
    )

    fileprivate static let allOperators = ["-", "/", "+", "*"]

    public func validate(file: SwiftLintFile) -> [StyleViolation] {
        guard let tree = file.syntaxTree.folded() else {
            return []
        }

        return Visitor(viewMode: .sourceAccurate)
            .walk(tree: tree, handler: \.violationPositions)
            .map { position in
                StyleViolation(ruleDescription: Self.description,
                               severity: configuration.severity,
                               location: Location(file: file, position: position))
            }
    }
}

private extension ShorthandOperatorRule {
    final class Visitor: SyntaxVisitor, ViolationsSyntaxVisitor {
        private(set) var violationPositions: [AbsolutePosition] = []

        override func visitPost(_ node: InfixOperatorExprSyntax) {
            guard node.operatorOperand.is(AssignmentExprSyntax.self),
                  let rightExpr = node.rightOperand.as(InfixOperatorExprSyntax.self),
                  let binaryOperatorExpr = rightExpr.operatorOperand.as(BinaryOperatorExprSyntax.self),
                  ShorthandOperatorRule.allOperators.contains(binaryOperatorExpr.operatorToken.withoutTrivia().text),
                  node.leftOperand.withoutTrivia().description == rightExpr.leftOperand.withoutTrivia().description
            else {
                return
            }

            violationPositions.append(node.leftOperand.positionAfterSkippingLeadingTrivia)
        }
    }
}
