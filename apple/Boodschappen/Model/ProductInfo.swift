import Foundation

/// Extra productinformatie van de productpagina op lidl.nl.
struct ProductInfo: Sendable, Equatable {
    var price: String?
    var description: String?
    var ean: String?

    var isEmpty: Bool { price == nil && description == nil && ean == nil }
}

/// Haalt de productpagina op en onthoudt het resultaat zolang de app draait.
actor ProductInfoLoader {
    static let shared = ProductInfoLoader()

    private var cache: [String: ProductInfo] = [:]

    func info(for urlString: String) async -> ProductInfo? {
        if let cached = cache[urlString] { return cached }
        guard let url = URL(string: urlString), url.host?.hasSuffix("lidl.nl") == true else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // lidl.nl geeft gewone browsers de volledige pagina.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("nl-NL,nl;q=0.9", forHTTPHeaderField: "Accept-Language")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8)
        else { return nil }

        let info = ProductInfoParser.parse(html: html)
        guard !info.isEmpty else { return nil }
        cache[urlString] = info
        return info
    }
}

/// Leest prijs, beschrijving en EAN-code uit de gestructureerde gegevens (JSON-LD)
/// van een productpagina, met de meta-omschrijving als reserve.
enum ProductInfoParser {
    static func parse(html: String) -> ProductInfo {
        var info = ProductInfo()

        for product in jsonLDProducts(in: html) {
            if info.description == nil, let text = product["description"] as? String {
                info.description = cleanText(text).nilIfEmpty
            }
            if info.price == nil {
                info.price = price(from: product["offers"])
            }
            if info.ean == nil {
                for key in ["gtin13", "gtin", "gtin8", "gtin14", "ean"] {
                    if let value = product[key] as? String, !value.isEmpty {
                        info.ean = value
                        break
                    }
                    if let value = product[key] as? NSNumber {
                        info.ean = value.stringValue
                        break
                    }
                }
            }
        }

        if info.description == nil {
            let meta = metaTags(in: html)
            if let text = meta["og:description"] ?? meta["description"] {
                info.description = cleanText(text).nilIfEmpty
            }
        }
        return info
    }

    // MARK: - JSON-LD

    static func jsonLDProducts(in html: String) -> [[String: Any]] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let text = html as NSString
        var products: [[String: Any]] = []
        for match in regex.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            let body = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            else { continue }
            collectProducts(json, into: &products)
        }
        return products
    }

    private static func collectProducts(_ json: Any, into products: inout [[String: Any]]) {
        if let array = json as? [Any] {
            for element in array {
                collectProducts(element, into: &products)
            }
            return
        }
        guard let object = json as? [String: Any] else { return }
        let type = object["@type"]
        if (type as? String) == "Product" || ((type as? [String])?.contains("Product") ?? false) {
            products.append(object)
        }
        if let graph = object["@graph"] {
            collectProducts(graph, into: &products)
        }
    }

    private static func price(from offers: Any?) -> String? {
        let list: [[String: Any]]
        if let offer = offers as? [String: Any] {
            list = [offer]
        } else if let array = offers as? [[String: Any]] {
            list = array
        } else {
            return nil
        }

        for offer in list {
            let raw = offer["price"] ?? offer["lowPrice"]
            let value: Double?
            if let number = raw as? NSNumber {
                value = number.doubleValue
            } else if let text = raw as? String {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
            guard let value, value > 0 else { continue }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "nl_NL")
            formatter.currencyCode = offer["priceCurrency"] as? String ?? "EUR"
            return formatter.string(from: NSNumber(value: value))
        }
        return nil
    }

    // MARK: - Meta-tags

    static func metaTags(in html: String) -> [String: String] {
        guard let tagRegex = try? NSRegularExpression(pattern: #"<meta\s[^>]*>"#, options: [.caseInsensitive]),
              let attributeRegex = try? NSRegularExpression(pattern: #"([a-zA-Z:_-]+)\s*=\s*"([^"]*)""#)
        else { return [:] }

        let text = html as NSString
        var result: [String: String] = [:]
        for tagMatch in tagRegex.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: tagMatch.range)
            let tagText = tag as NSString
            var attributes: [String: String] = [:]
            for match in attributeRegex.matches(in: tag, range: NSRange(location: 0, length: tagText.length)) {
                let name = tagText.substring(with: match.range(at: 1)).lowercased()
                attributes[name] = tagText.substring(with: match.range(at: 2))
            }
            if let key = attributes["property"] ?? attributes["name"], let content = attributes["content"] {
                result[key.lowercased()] = decodeEntities(content)
            }
        }
        return result
    }

    // MARK: - Tekst opschonen

    static func cleanText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: #"</(p|li|div|h\d)>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: #"<li[^>]*>"#, with: "• ", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        result = decodeEntities(result)
        result = result.replacingOccurrences(of: #"[ \t\u{00A0}]+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #" *\n *"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text

        if let regex = try? NSRegularExpression(pattern: "&#([xX]?)([0-9a-fA-F]+);") {
            let source = result as NSString
            var decoded = ""
            var position = 0
            for match in regex.matches(in: result, range: NSRange(location: 0, length: source.length)) {
                decoded += source.substring(with: NSRange(location: position, length: match.range.location - position))
                let isHex = !source.substring(with: match.range(at: 1)).isEmpty
                let digits = source.substring(with: match.range(at: 2))
                if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                    decoded.append(Character(scalar))
                } else {
                    decoded += source.substring(with: match.range)
                }
                position = match.range.location + match.range.length
            }
            decoded += source.substring(from: position)
            result = decoded
        }

        let named: [(String, String)] = [
            ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "),
            ("&euro;", "€"), ("&eacute;", "é"), ("&euml;", "ë"), ("&egrave;", "è"), ("&iuml;", "ï"),
            ("&ouml;", "ö"), ("&uuml;", "ü"), ("&agrave;", "à"), ("&ccedil;", "ç"), ("&deg;", "°"),
            ("&amp;", "&"),
        ]
        for (entity, value) in named {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
