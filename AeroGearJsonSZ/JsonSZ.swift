/*
* JBoss, Home of Professional Open Source.
* Copyright Red Hat, Inc., and individual contributors
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

/**
A class must implement this protocol to signal that is JSON serializable
*/
public protocol JSONSerializable {
    
    /**
    A default constructor
    */
    init()
    
    /**
    Called by the library to construct an object. 
    
    Note:  The user doesn't need to invoke it directly, but would be called automatically by the
    library during construction of the object
    
    :param: source      the JsonSZ object that performs the serialization
    :param: Self           the object that is constructed.
    */
    class func map(source: JsonSZ, object: Self)
}

enum Operation {
    case fromJSON
    case toJSON
}

/**
Main class that provides convenient methods for serializing/deserializing from/to JSON structures
*/
public class JsonSZ {
    var values: [String:  AnyObject] = [:]

    var key: String?
    var value: AnyObject?
    
    var operation: Operation = .fromJSON
    
    public init() {}
    
    public subscript(key: String) -> JsonSZ {
        get {
            self.key = key
            self.value = self.values[key]
            
            return self
        }
    }
    
    /**
    Deserialize from JSON
    
    :param: JSON      the JSON structure
    :param: type        the type of the object to be constructed
    
    :returns: the object initialized from the JSON structure
    */
    public func fromJSON<N: JSONSerializable>(JSON: AnyObject,  to type: N.Type) -> N {
        if let string = JSON as? String {
            if let data =  JSON.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true) {
               self.values = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: nil) as [String: AnyObject]
            }
        } else if let dictionary = JSON as? [String: AnyObject] {
            self.values = dictionary
        }

        var object = N()
        N.map(self, object: object)
        return object
    }
    
    /**
    Deserialize from JSON Array
    
    :param: JSON      the top-level JSON array that wraps the objects
    :param: type        the type of the object to be constructed
    
    :returns: the array of objects initialized from the JSON structure
    */
    public func fromJSONArray<N: JSONSerializable>(JSON: AnyObject,  to type: N.Type) -> [N]? {
        if let string = JSON as? String {
            if let data =  JSON.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true) {
                let parsed: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: nil)
                if let array = parsed as? [[String: AnyObject]] {
                    var objects: [N] = []
                    
                    for element in array {
                        self.values = element
                        var object = N()
                        N.map(self, object: object)
                        objects.append(object)
                    }
                    
                    return objects
                }
            }
        }

        return nil
    }
    
    /**
    Serialize type to JSON
    
    :param: object     a JSONSerializable object from which JSON would be constructed
    :param: type        the type of the object to be constructed
    
    :returns: the array of objects initialized from the JSON structure
    */
    public func toJSON<N: JSONSerializable>(object: N) -> [String:  AnyObject] {
        operation = .toJSON
        
        self.values = [String : AnyObject]()
        N.map(self, object: object)
        
        return self.values
    }
}

// primitive types
public func <=<T>(inout left: T?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<T>().primitiveType(&left, value: right.value)
    } else {
        ToJSON().primitiveType(left, key: right.key!, dictionary: &right.values)
    }
}

// object types
public func <=<T: JSONSerializable>(inout left: T?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<T>().objectType(&left, value: right.value)
    } else {
        ToJSON().objectType(left, key: right.key!, dictionary: &right.values)
    }
}

// array
public func <=<T: JSONSerializable>(inout left: [T]?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<T>().arrayType(&left, value: right.value)
    } else {
        ToJSON().arrayType(left, key: right.key!, dictionary: &right.values)
    }
}

// array primitives
public func <=(inout left: [AnyObject]?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<AnyObject>().primitiveType(&left, value: right.value)
    } else {
        ToJSON().arrayType(left, key: right.key!, dictionary: &right.values)
    }
}

// dictionary
public func <=<T: JSONSerializable>(inout left: [String:  T]?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<T>().dictionaryType(&left, value: right.value)
    } else {
        ToJSON().dictionaryType(left, key: right.key!, dictionary: &right.values)
    }
}

// dictionary primitives
public func <=(inout left: [String:  AnyObject]?, right: JsonSZ) {
    if right.operation == .fromJSON {
        FromJSON<AnyObject>().primitiveType(&left, value: right.value)
    } else {
        ToJSON().dictionaryType(left, key: right.key!, dictionary: &right.values)
    }
}

class FromJSON<CollectionType> {
    
    func primitiveType<FieldType>(inout field: FieldType?, value: AnyObject?) {
        if let value: AnyObject = value {
            switch FieldType.self {
            case is String.Type:
                field = value as? FieldType
            case is Bool.Type:
                field = value as? FieldType
            case is Int.Type:
                field = value as? FieldType
            case is Double.Type:
                field = value as? FieldType
            case is Float.Type:
                field = value as? FieldType
            case is Array<CollectionType>.Type:
                field = value as? FieldType
            case is Dictionary<String, CollectionType>.Type:
                field = value as? FieldType
            case is NSDate.Type:
                field = value as? FieldType
            default:
                field = nil
                return
            }
        }
    }

    func objectType<N: JSONSerializable>(inout field: N?, value: AnyObject?) {
        if let value = value as? [String:  AnyObject] {
            field = JsonSZ().fromJSON(value, to: N.self)
        }
    }
        
    func arrayType<N: JSONSerializable>(inout field: [N]?, value: AnyObject?) {
        let serializer = JsonSZ()
        
        var objects = [N]()

        if let array = value as [AnyObject]? {
            for object in array {
                var object = serializer.fromJSON(object as [String: AnyObject],  to: N.self)
                objects.append(object)
            }
        }
        
        field = objects.count > 0 ? objects: nil
    }
        
    func dictionaryType<N: JSONSerializable>(inout field: [String: N]?, value: AnyObject?) {
        let serializer = JsonSZ()
        
        if let dictionary = value as? [String: AnyObject] {
            var objects = [String: N]()
            
            for (key, object) in dictionary {
                var object = serializer.fromJSON(object as [String:  AnyObject], to: N.self)
                objects[key] = object
            }

            field = objects.count > 0 ? objects: nil
        }
    }
}

class ToJSON {

    func primitiveType<N>(field: N?, key: String, inout dictionary: [String : AnyObject]) {
        if let field: N = field {
            switch N.self {
            case is Bool.Type:
                dictionary[key] = field as Bool
            case is Int.Type:
                dictionary[key] = field as Int
            case is Double.Type:
                dictionary[key] = field as Double
            case is Float.Type:
                dictionary[key] = field as Float
            case is String.Type:
                dictionary[key] = field as String
            default:
                return
            }
        }
    }
    
    func objectType<N: JSONSerializable>(field: N?, key: String, inout dictionary: [String : AnyObject]) {
        if let field = field {
            dictionary[key] = NSDictionary(dictionary: JsonSZ().toJSON(field))
        }
    }
    
    func arrayType<N: JSONSerializable>(field: [N]?, key: String, inout dictionary: [String : AnyObject]) {
        if let field = field {
            var objects = NSMutableArray()
            
            for object in field {
                objects.addObject(JsonSZ().toJSON(object))
            }
            
            if objects.count > 0 {
                dictionary[key] = objects
            }
        }
    }
    
   func arrayType(field: [AnyObject]?, key: String, inout dictionary: [String : AnyObject]) {
        if let value = field {
            dictionary[key] = NSArray(array: value)
        }
    }
    
    func dictionaryType<N: JSONSerializable>(field: [String: N]?, key: String, inout dictionary: [String : AnyObject]) {
        if let field = field {
            var objects = NSMutableDictionary()
            
            for (key, object) in field {
                objects.setObject(JsonSZ().toJSON(object), forKey: key)
            }
            
            if objects.count > 0 {
                dictionary[key] = objects
            }
        }
    }
    
    func dictionaryType(field: [String: AnyObject]?, key: String, inout dictionary: [String : AnyObject]) {
        if let value = field {
            dictionary[key] = NSDictionary(dictionary: value)
        }
    }
    
}