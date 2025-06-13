import SwiftUI

struct ContentView: View {
    
    @State private var count: Int = 0
    @State private var name: String = ""
    
    var body: some View {
        
        VStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.largeTitle)
            TextField("Hello", text: $name)
            HStack {
                ZStack {
                    Text("OK?")
                    
                }
                

                VStack {
                    List(0..<4) { i in Text("Hello, World! \(i) \(count)") }.padding(10)
                    Button(action: {
                        print("Click Button \(count)")
                        count += 1
                        
                    }, label: {VStack{Text("Press Me")}})
                }.padding(9)
            }
            
        }.padding(10)
    }
}


#Preview {
    ContentView()
}



