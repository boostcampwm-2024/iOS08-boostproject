import CommonCrypto
import Foundation

import BaseDomain
import NetworkModule

public enum LiveStationEndpoint {
    case fetchChannelList
    case receiveBroadcast(channelId: String)
    case fetchThumbnail(channelId: String)
    case makeChannel(channelName: String)
    case deleteChannel(channelId: String)
    case fetchChannelInfo(channelId: String)
}

extension LiveStationEndpoint: Endpoint {
    public var method: NetworkModule.HTTPMethod {
        switch self {
        case .fetchChannelList, .receiveBroadcast, .fetchThumbnail, .fetchChannelInfo: .get
        case .makeChannel: .post
        case .deleteChannel: .delete
        }
    }
    
    public var header: [String: String]? {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        return [
            "x-ncp-apigw-timestamp": timestamp,
            "x-ncp-iam-access-key": config(key: .accessKey),
            "x-ncp-apigw-signature-v2": makeSignature(with: timestamp),
            "x-ncp-region_code": "KR"
        ]
    }
    
    public var host: String {
        "livestation.apigw.ntruss.com"
    }
    
    public var path: String {
        switch self {
        case .fetchChannelList, .makeChannel: "/api/v2/channels"
        case let .receiveBroadcast(channelId), let .fetchThumbnail(channelId): "/api/v2/channels/\(channelId)/serviceUrls"
        case let .deleteChannel(channelId), let .fetchChannelInfo(channelId): "/api/v2/channels/\(channelId)"
        }
    }
    
    public var requestTask: NetworkModule.RequestTask {
        switch self {
        case .fetchChannelList:
            return .withParameters(
                query: ["channelStatus": "PUBLISHING"]
            )
            
        case .receiveBroadcast:
            return .withParameters(
                query: ["serviceUrlType": ServiceUrlType.timemachine.rawValue]
            )
            
        case .fetchThumbnail:
            return .withParameters(
                query: ["serviceUrlType": ServiceUrlType.thumbnail.rawValue]
            )
            
        case let .makeChannel(channelName):
            return .withParameters(
                body: [
                    "channelName": channelName,
                    "cdn": [
                        "createCdn": false,
                        "cdnType": "GLOBAL_EDGE",
                        "cdnDomain": config(key: .cdnDomain),
                        "profileId": config(key: .profileID),
                        "cdnInstanceNo": config(key: .cdnInstanceNo),
                        "regionType": "KOREA"
                    ],
                    "qualitySetId": 4430,
                    "useDvr": true,
                    "immediateOnAir": true,
                    "record": [
                        "type": "MANUAL_UPLOAD"
                    ],
                    "drmEnabledYn": false,
                    "timemachineMin": 360
                ]
            )
            
        case .deleteChannel, .fetchChannelInfo: return .empty
        }
    }
}

private extension LiveStationEndpoint {
    func makeQueryString(with query: Parameters) -> String {
        return "?" + query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }
    
    func makeSignature(with timestamp: String) -> String {
        let space = " "
        let newLine = "\n"
        let method = method
        let accessKey = config(key: .accessKey)
        let secretKey = config(key: .secretKey)
        let timestamp = timestamp
        
        var url = path
        switch requestTask {
        case .empty:
            break
            
        case let .withParameters(_, query, _, _), let .withObject(_, query, _):
            if let query {
                let queryString = makeQueryString(with: query)
                url.append(queryString)
            }
        }

        // 메시지 생성
        let message = "\(method)\(space)\(url)\(newLine)\(timestamp)\(newLine)\(accessKey)"

        // HMAC SHA256으로 서명 생성
        guard let keyData = secretKey.data(using: .utf8),
              let messageData = message.data(using: .utf8) else {
            return ""
        }

        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        messageData.withUnsafeBytes { messageBytes in
            keyData.withUnsafeBytes { keyBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, keyData.count, messageBytes.baseAddress, messageData.count, &hmac)
            }
        }

        let hmacData = Data(hmac)
        let base64Signature = hmacData.base64EncodedString()
        
        return base64Signature
    }
}
