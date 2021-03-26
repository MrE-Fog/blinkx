//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


import SwiftUI

fileprivate struct CardRow: View {
  var key: BKPubKey
  let currentKey: String
  
  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(key.id)
        Text(key.keyType ?? "").font(.footnote)
      }.contentShape(Rectangle())
      Spacer()
      Checkmark(checked: key.id == currentKey)
    }.contentShape(Rectangle())
  }
}

@objc public protocol KeysPickerViewDelegate {
  @objc func didPickKey(key: String)
}

struct KeysPickerView: View {
  var currentKey: String
  var delegate: KeysPickerViewDelegate
  
  @State private var list: [BKPubKey] = Array<BKPubKey>(BKPubKey.all())
  
  var body: some View {
    List {
      HStack {
        Text("None")
      }
      .contentShape(Rectangle())
      .onTapGesture {
        delegate.didPickKey(key: "")
      }
      ForEach(list, id: \.tag) { key in
        CardRow(key: key, currentKey: currentKey)
          .onTapGesture {
            delegate.didPickKey(key: key.id)
          }
      }
    }
    .navigationTitle("Select Key")
  }
}