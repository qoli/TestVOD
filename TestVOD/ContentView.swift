//
//  ContentView.swift
//  TestVOD
//
//  Created by 黃佁媛 on 2023/2/1.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("vodText") private var vodText: String = ""

    @State var result: [String] = []

    @State var show: Bool = false
    @State var text: String = "test"
    @State var textL: String = "test"
    @State var textR: String = ""

    var body: some View {
        VStack {
            TextEditor(text: $vodText)
            HStack {
                Button {
                    Task {
                        await appear()
                    }
                } label: {
                    Text("Test")
                }

                Button {
                    show.toggle()
                } label: {
                    Text("Show")
                }
            }
        }
        .sheet(isPresented: $show, content: {
            List {
                Section(header: Text("上次結果")) {
                    HStack {
                        Text(textL)
                            .lineLimit(1)
                            .font(.caption2)

                        Spacer()

                        Text(textR)
                            .font(.caption2)
                            .lineLimit(1)
                    }
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

                Section {
                    ForEach(result, id: \.self) { api in
                        Text(api)
                            .textSelection(.enabled)
                    }
                }
            }

            .animation(.easeInOut, value: text)
            .animation(.easeInOut, value: result.count)
        })
        .padding()
        .task {
            await appear()
        }
    }

    @State var i = 0
    @State var c = 0

    func appear() async {
        show = true

        let list = vodText.regex(for: #"http(.*)\/api\.php\/provide\/vod\/at\/xml"#)

        c = list.count

        for str in list {
            i = i + 1
            if let apiURL = URL(string: str.first ?? "") {
                text = apiURL.description
                print(apiURL.description)
                if let time = await apiURL.responseTimeAsync() {
                    print("...", time.description)
                    let r = await search(keyword: "娱乐百分百", vodURL: apiURL.description)

                    textL = apiURL.description
                    textR = "\(time.description) - \(r ?? "nil")"

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

//                if let time = await apiURL.responseTimeAsync() {

//

//                }
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
