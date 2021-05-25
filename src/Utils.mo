import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Char "mo:base/Char";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import SHA224 "mo:sha224/SHA224";
import CRC32 "./CRC32";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Text "mo:base/Text"

module {
    private let symbols = [
        '0', '1', '2', '3', '4', '5', '6', '7',
        '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
    ];
    private let base : Nat8 = 0x10;

    /// account identitier
    public type AccountIdentifier = {
        hash: [Nat8];
    };

    public func encode(array : [Nat8]) : Text {
        Array.foldLeft<Nat8, Text>(array, "", func (accum, u8) {
            accum # nat8ToText(u8);
        });
    };

    func nat8ToText(u8: Nat8) : Text {
        let c1 = symbols[Nat8.toNat((u8/base))];
        let c2 = symbols[Nat8.toNat((u8%base))];
        return Char.toText(c1) # Char.toText(c2);
    };

    public func hash(a: AccountIdentifier) : Hash.Hash {
        var array : [Hash.Hash] = [];
        var temp : Hash.Hash = 0;
        for (i in a.hash.vals()) {
            temp := Hash.hash(Nat8.toNat(i));
            array := Array.append<Hash.Hash>(array, Array.make<Hash.Hash>(temp));
        };

        return Hash.hashNat8(array);
    };

    public func equal(a: AccountIdentifier, b: AccountIdentifier) : Bool {
        Array.equal<Nat8>(a.hash, b.hash, Nat8.equal)
    };

    /// Return the Account Identifier of the Principal.
    public func principalToAccount(p : Principal) : AccountIdentifier {
        let digest = SHA224.Digest();
        digest.write([10, 97, 99, 99, 111, 117, 110, 116, 45, 105, 100]:[Nat8]); // b"\x0Aaccount-id"
        let blob = Principal.toBlob(p);
        digest.write(Blob.toArray(blob));
        digest.write(Array.freeze<Nat8>(Array.init<Nat8>(32, 0 : Nat8))); // sub account
        let hash_bytes = digest.sum();

        return {hash=hash_bytes;}: AccountIdentifier;
    };

    /// Return the Text of the Account Identifier.
    public func accountToText(p : AccountIdentifier) : Text {
        let crc = CRC32.crc32(p.hash);
        let aid_bytes = Array.append<Nat8>(crc, p.hash);

        return encode(aid_bytes);
    };

    /// Return the Account Identifier of the Text.
    public func textToAccount(t : Text) : AccountIdentifier {
        var map = HashMap.HashMap<Nat, Nat8>(1, Nat.equal, Hash.hash);
        // '0': 48 -> 0; '9': 57 -> 9
        for (num in Iter.range(48, 57)) {
            map.put(num, Nat8.fromNat(num-48));
        };
        // 'a': 97 -> 10; 'f': 102 -> 15
        for (lowcase in Iter.range(97, 102)) {
            map.put(lowcase, Nat8.fromNat(lowcase-97+10));
        };
        // 'A': 65 -> 10; 'F': 70 -> 15
        for (uppercase in Iter.range(65, 70)) {
            map.put(uppercase, Nat8.fromNat(uppercase-65+10));
        };
        let p = Iter.toArray(Iter.map(Text.toIter(t), func (x: Char) : Nat { Nat32.toNat(Char.toNat32(x)) }));
        var res : [var Nat8] = [var];
        
        for (i in Iter.range(4, 31)) {            
            let a = Option.unwrap(map.get(p[i*2]));
            let b = Option.unwrap(map.get(p[i*2 + 1]));
            let c = 16*a + b;
            res := Array.thaw(Array.append(Array.freeze(res), Array.make(c)));
        };
        let result = Array.freeze(res);
        return {hash = result;} : AccountIdentifier;
    };
};