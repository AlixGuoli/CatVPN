import Alamofire

enum LinkReachability {

    static var isOnline: Bool {
        NetworkReachabilityManager()?.isReachable == true
    }
}
