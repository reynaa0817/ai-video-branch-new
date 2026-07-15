package json

import (
	"encoding/json"
)

// Read parses []byte in the json format into map.
func Read(b []byte) (map[string]interface{}, error) {
	var ret map[string]interface{}
	err := json.Unmarshal(b, &ret)
	if err != nil {
		return nil, err
	}
	return ret, nil
}

// ReadFlattenedMap parses []byte in the json format into flattened map.
// func ReadFlattenedMap(b []byte) (map[string]interface{}, error) {
// 	tree, err := Read(b)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return conf.GetFlattenedMap(tree)

// }
