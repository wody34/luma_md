import Foundation

enum ReaderStyles {
    static func css(typeScale: ReaderTypeScale) -> String {
        let scale = scaleValue(typeScale)
        return """
        :root{--reader-measure:45rem;--canvas:#0E0D13;--surface:#17151F;--surface-raised:#201D2B;\
        --text:#F5F1FA;--muted:#A8A0B4;--border:#393346;--border-soft:#2B2637;\
        --accent:#9566F5;--accent-soft:#2E2147;--code:#111018;--type-scale:\(scale)}
        [data-theme=light]{--canvas:#F3F0F7;--surface:#FCFAFE;--surface-raised:#FFFFFF;\
        --text:#201B27;--muted:#706878;--border:#D7D0DF;--border-soft:#E7E1EC;\
        --accent:#7044D4;--accent-soft:#EEE6FF;--code:#F2EEF6}
        @media(min-width:1200px){:root{--reader-measure:60rem}}
        @media(min-width:1600px){:root{--reader-measure:68rem}}
        *{box-sizing:border-box}
        html{color-scheme:dark light;background:var(--canvas);scroll-behavior:smooth}
        body{margin:0;min-height:100vh;-webkit-user-select:none;user-select:none;\
        color:var(--text);background:radial-gradient(circle at 50% -15%,\
        color-mix(in srgb,var(--accent) 15%,transparent),transparent 42%),var(--canvas);\
        font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",sans-serif;\
        font-size:calc(17px * var(--type-scale));line-height:1.72}
        a{color:var(--accent)}
        .page{width:min(100%,1240px);margin:0 auto;padding:44px 28px 120px}
        .document-head,.reader-wrap{width:min(100%,var(--reader-measure))}
        .document-head{margin:0 auto 28px}
        .eyebrow{display:flex;align-items:center;gap:10px;color:var(--accent);\
        font-size:12px;font-weight:750;letter-spacing:.16em;text-transform:uppercase}
        .eyebrow::before{content:"";width:38px;height:2px;background:var(--accent)}
        h1.document-title{font-family:ui-serif,Georgia,serif;\
        font-size:calc(44px * (1 + (var(--type-scale) - 1)*.5));line-height:1.08;\
        letter-spacing:-.035em;margin:18px 0}
        .metadata{display:flex;flex-wrap:wrap;gap:10px 22px;color:var(--muted);font-size:14px}
        .reader-wrap{margin:0 auto}
        .reader-surface{-webkit-user-select:text;user-select:text;padding:42px 46px;\
        overflow-wrap:anywhere;border:1px solid var(--border-soft);border-radius:24px;\
        background:var(--surface);box-shadow:0 22px 70px rgba(0,0,0,.18)}
        .reader-surface>:first-child{margin-top:0}
        .reader-surface>:last-child{margin-bottom:0}
        .reader-surface h1,.reader-surface h2{font-family:ui-serif,Georgia,serif;\
        letter-spacing:-.025em}
        .reader-surface h1{font-size:calc(36px * (1 + (var(--type-scale) - 1)*.5));\
        line-height:1.16;margin:0 0 24px}
        .reader-surface h2{font-size:calc(27px * (1 + (var(--type-scale) - 1)*.5));\
        line-height:1.25;margin:36px 0 16px}
        .reader-surface h3{font-size:calc(20px * (1 + (var(--type-scale) - 1)*.5));\
        margin:30px 0 12px}
        .reader-surface p{margin:0 0 18px}
        .reader-surface ul,.reader-surface ol{padding-left:26px;margin:0 0 20px}
        .reader-surface li{margin:7px 0}
        .reader-surface blockquote{margin:24px 0;padding:16px 20px;\
        border-left:3px solid var(--accent);background:var(--accent-soft);border-radius:0 14px 14px 0}
        .reader-surface code{font-family:ui-monospace,"SFMono-Regular",Menlo,monospace;\
        font-size:.88em;padding:.14em .38em;background:var(--code);border:1px solid var(--border-soft);\
        border-radius:6px}
        .reader-surface pre{position:relative;overflow:auto;margin:24px 0;padding:22px;\
        background:var(--code);border:1px solid var(--border-soft);border-radius:16px}
        .reader-surface pre code{padding:0;border:0;background:none;white-space:pre}
        .math-inline,.math-block{font-family:ui-serif,Georgia,serif;\
        font-variant-numeric:lining-nums;font-style:normal}
        .math-inline{display:inline-flex;align-items:center;vertical-align:middle;\
        max-width:100%;margin:0 .08em}
        .math-inline math{font-size:1.08em;max-width:100%}
        .math-block{display:flex;justify-content:center;overflow-x:auto;margin:26px 0;\
        padding:20px 24px;color:var(--text);background:var(--accent-soft);\
        border:1px solid color-mix(in srgb,var(--accent) 24%,var(--border-soft));\
        border-radius:14px}
        .math-block math{display:block;min-width:max-content;font-size:1.18em;line-height:1.35}
        .math-block mtable{margin:0 auto}
        .table-scroll{overflow-x:auto;margin:24px 0;border:1px solid var(--border);\
        border-radius:14px}
        table{width:100%;border-collapse:collapse}
        th,td{padding:12px 14px;text-align:left;border-bottom:1px solid var(--border-soft)}
        th{background:var(--surface-raised);font-size:.8em;letter-spacing:.05em;text-transform:uppercase}
        hr{border:0;border-top:1px solid var(--border);margin:38px 0}
        .unsafe-link{color:var(--muted);text-decoration:line-through}
        @media(max-width:760px){.page{padding:28px 16px 100px}.reader-surface{padding:28px 22px}}
        @media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
        """
    }

    private static func scaleValue(_ scale: ReaderTypeScale) -> String {
        switch scale {
        case .small:
            return "0.92"
        case .standard:
            return "1"
        case .large:
            return "1.12"
        }
    }
}
