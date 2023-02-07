//
//  ContentView.swift
//  TestVOD
//
//  Created by 黃佁媛 on 2023/2/1.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("vodText") private var vodText: String = ""
    @AppStorage("reg") var reg: String = #"http(.*)\/api\.php\/provide\/vod\/at\/xml"#
    @AppStorage("keyword") var keyword: String = "娱乐百分百"

    @State var result: [String] = []

    @State var show: Bool = false
    @State var text: String = "等待開始"
    @State var textL: String = "等待開始"
    @State var textR: String = "等待開始"

    
    
    var body: some View {
        List {
            Section(header: Text("匹配正則")) {
                TextField("正則", text: $reg)
            }

            Section(header: Text("內容")) {
                TextField("Keyword", text: $keyword)
                TextEditor(text: $vodText)
                    .frame(height: 300)
            }

            Button {
                Task {
                    await appear()
                }
            } label: {
                Text("開始測試")
            }

            Button {
                show.toggle()
            } label: {
                Text("顯示結果")
            }
        }

        .navigationTitle("VOD 地址格式測試")
        .sheet(isPresented: $show, content: {
            List {
                #if targetEnvironment(macCatalyst)
                    Button {
                        show.toggle()
                    } label: {
                        Text("關閉窗口")
                    }
                #endif

                Section(header: Text("上次結果")) {
                    Text(textL)
                        .lineLimit(1)
                        .font(.caption2)

                    Text(textR)
                        .font(.caption2)
                        .lineLimit(5)
                }

                Section(header: Text("正在測試")) {
                    HStack {
                        Text(text)
                            .font(.caption2)
                            .lineLimit(1)

                        Spacer()

                        Text("\(i)/\(c)")
                            .font(.caption2)
                    }
                }

                Section(header: Text("通過測試的 VOD")) {
                    if result.count == 0 {
                        Text("尚未發現")
                    }

                    ForEach(result, id: \.self) { api in
                        HStack {
                            Text(api)
                                .font(.caption2)
                                .textSelection(.enabled)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                #if os(iOS)
                                    UIPasteboard.general.string = api
                                #endif

                                #if os(macOS)
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.declareTypes([.string], owner: nil)
                                    pasteboard.setString(api, forType: .string)
                                #endif
                            } label: {
                                Text("複製")
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: text)
            .animation(.easeInOut, value: result.count)
        })
    }

    @State var i = 0
    @State var c = 0

    func appear() async {
        show = true

        let list = vodText.regex(for: reg)

        c = list.count

        for str in list {
            i = i + 1
            if let apiURL = URL(string: str.first ?? "") {
                text = apiURL.description
                print(apiURL.description)
                if let time = await apiURL.responseTimeAsync() {
                    print("...", time.description)
                    let r = await search(keyword: keyword, vodURL: apiURL.description)

                    textL = apiURL.description
                    textR = "\(r ?? "nil")"

                    if r?.contains("m3u8") == true {
                        print("### ->", apiURL.description, "<- ###")
                        result.append(apiURL.description)
                        print(r ?? "nil")
                        print("... ### ...")
                    } else {
                        let rr = r?.regex(for: #"<title>(.*)</title>"#)
                        print("No M3U8", rr?.first?.first ?? "no title")
                    }
                } else {
                    print("... timeout")
                    textL = apiURL.description
                    textR = "timeout"
                }
            }
        }
    }

    func search(keyword: String, vodURL: String) async -> String? {
        let para = [
            "wd": keyword,
            "ac": "videolist",
        ]

        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
            "Content-Type": "text/xml; charset=utf-8",
        ]

        let api = await api(withURLString: vodURL, parameters: para)
        await api.setFixUTF8()
        await api.setHeaders(headers: headers)
        let xmlString = try? await api.exec()

        return xmlString
    }
}
