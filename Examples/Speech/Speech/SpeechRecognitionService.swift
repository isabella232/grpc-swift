//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import Foundation

let API_KEY : String = "AIzaSyAZSuTl9SvDuuU2jc1Ajw5WEoa_O6ttlCo"
let HOST = "speech.googleapis.com"

typealias SpeechRecognitionCompletionHandler = (Any?, NSError?) -> (Void)

class SpeechRecognitionService {
  var sampleRate: Int = 16000
  private var nowStreaming = false

  var fileDescriptorSet : FileDescriptorSet
  var client: Client
  var call: Call?

  static let sharedInstance = SpeechRecognitionService()

  private init() {
    fileDescriptorSet = FileDescriptorSet(filename: "speech.out")
    client = Client(address:HOST, certificates: nil, host: nil)
  }

  func streamAudioData(_ audioData: NSData, completion: SpeechRecognitionCompletionHandler) {

    if (!nowStreaming) {
      // if we aren't already streaming, set up a gRPC connection
      call = client.createCall(host: HOST,
                               method: "/google.cloud.speech.v1beta1.Speech/StreamingRecognize",
                               timeout: 120.0)

      if let call = call {
        let metadata = Metadata(["x-goog-api-key":API_KEY,
                                 "x-ios-bundle-identifier":Bundle.main.bundleIdentifier!])
        call.start(metadata:metadata)

        let recognitionConfig = fileDescriptorSet.createMessage("RecognitionConfig")!
        recognitionConfig.addField("encoding", value: 1)
        recognitionConfig.addField("sample_rate", value: self.sampleRate)
        recognitionConfig.addField("language_code", value: "en-US")
        recognitionConfig.addField("max_alternatives", value: 30)

        let streamingRecognitionConfig = fileDescriptorSet.createMessage("StreamingRecognitionConfig")!
        streamingRecognitionConfig.addField("config", value: recognitionConfig)
        streamingRecognitionConfig.addField("single_utterance", value: false)
        streamingRecognitionConfig.addField("interim_results", value: true)

        let streamingRecognizeRequest = fileDescriptorSet.createMessage("StreamingRecognizeRequest")!
        streamingRecognizeRequest.addField("streaming_config", value:streamingRecognitionConfig)

        let messageData = streamingRecognizeRequest.data()
        call.sendMessage(data:messageData)
        nowStreaming = true

        self.receiveMessage()
      }
    }

    if let call = call {
      let streamingRecognizeRequest = fileDescriptorSet.createMessage("StreamingRecognizeRequest")!
      streamingRecognizeRequest.addField("audio_content", value: audioData)
      let messageData = streamingRecognizeRequest.data()
      call.sendMessage(data:messageData)
    }
  }

  func receiveMessage() {
    if let call = call {
      call.receiveMessage() {(data) in
        if let data = data {
          if let responseMessage =
            self.fileDescriptorSet.readMessage("StreamingRecognizeResponse", data:data) {
            responseMessage.forEachField("results") {(field) in
              field.message().forOneField("is_final") {(field2) in
                field.message().forOneField("alternatives") {(field3) in
                  let alternativeMessage = field3.message()
                  if let transcript = alternativeMessage.oneField("transcript") {
                    print(transcript.string())
                  }
                }
              }
            }
          }
        }
        self.receiveMessage()
      }
    }
  }

  func stopStreaming() {
    if (!nowStreaming) {
      return
    }
    nowStreaming = false
    if let call = call {
      call.close {}
    }
  }
  
  func isStreaming() -> Bool {
    return nowStreaming
  }
}
