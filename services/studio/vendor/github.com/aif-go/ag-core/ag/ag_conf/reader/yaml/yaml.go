package yaml

import (
	"gopkg.in/yaml.v3" // TODO use yaml.v3
)

// Read parses []byte in the yaml format into map.
func Read(b []byte) (map[string]interface{}, error) {
	ret := make(map[string]interface{})
	err := yaml.Unmarshal(b, &ret)
	if err != nil {
		return nil, err
	}
	return ret, nil
}

// ReadFlattenedMap parses []byte in the yaml format into flattened map.
// func ReadFlattenedMap(b []byte) (map[string]interface{}, error) {
// 	ret, err := Read(b)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return conf.GetFlattenedMap(ret)
// }
