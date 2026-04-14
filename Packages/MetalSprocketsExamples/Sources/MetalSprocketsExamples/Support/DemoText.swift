import CoreText
import SwiftUI

enum DemoText {
    static var attributedString: NSAttributedString {
        let fancyFont = CTFontCreateWithName("Zapfino" as CFString, 12, nil)
        let defaultFont = CTFontCreateWithName("HelveticaNeue" as CFString, 12, nil)
        let sfSymbolsFont = CTFontCreateWithName("SF Pro" as CFString, 24, nil)

        let text = NSMutableAttributedString(string: "This is Slug rendered with Metal\n")
        let codepointCount = text.length

        // Rainbow colors for the header
        for i in 0..<codepointCount {
            let hue = Float(i) / Float(codepointCount - 1)
            let rgb = rgbFromHue(hue)
            let color = CGColor(srgbRed: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
            text.addAttributes([
                .font: fancyFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: color
            ], range: NSRange(location: i, length: 1))
        }

        // Hello World in many languages
        let phrases = [
            "Hello, World\n",
            "Bonjour, le monde\n",
            "Hola, mundo\n",
            "Hallo Welt\n",
            "Ciao, mondo\n",
            "Olá, mundo\n",
            "Hej, världen\n",
            "Hei, verden\n",
            "こんにちは、世界\n",
            "สวัสดีชาวโลก\n",
            "你好，世界\n",
            "مرحبًا بالعالم\n",
            "नमस्ते, दुनिया\n",
            "Привет, мир\n",
            "Γεια σου, κόσμε\n",
            "שלום, עולם\n",
            "안녕하세요, 세계\n",
            "ሰላም ልዑል\n",
            "გამარჯობა სამყარო\n",
            "Բարեւ, աշխարհ\n",
            "မင်္ဂလာပါ၊ ကမ္ဘာလောက\n",
            "හෙලෝ වර්ල්ඩ්\n",
            "សួស្តី​ពិភពលោក\n",
            "ᠰᠠᠶᠢᠨ ᠳᠡᠯᠡᠬᠡᠢ\n",
            "வணக்கம், உலகம்\n",
            "হ্যালো, বিশ্ব\n",
            "سلام دنیا\n",
            "హలో, ప్రపంచం\n"
        ]

        for phrase in phrases {
            text.append(NSAttributedString(string: phrase, attributes: [
                .font: defaultFont,
                .foregroundColor: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            ]))
        }

        // SF Symbols
        text.append(NSAttributedString(string: "􀍟􀺺􀥎􀆔\n", attributes: [
            .font: sfSymbolsFont,
            .foregroundColor: CGColor(srgbRed: 1, green: 1, blue: 0, alpha: 1)
        ]))

        // Emojis - NOTE: these don't render (Slug doesn't support bitmap/color glyphs yet?)
        text.append(NSAttributedString(string: "❤️\n", attributes: [
            .font: defaultFont
        ]))

        return text
    }
}
