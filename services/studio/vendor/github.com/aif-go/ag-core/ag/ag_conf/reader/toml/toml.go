package toml

import (
	"github.com/pelletier/go-toml"
)

// Read parses []byte in the toml format into map.
func Read(b []byte) (map[string]interface{}, error) {
	tree, err := toml.LoadBytes(b)
	if err != nil {
		return nil, err
	}
	return tree.ToMap(), nil
}

// ReadFlattenedMap parses []byte in the toml format into flattened map.
// func ReadFlattenedMap(b []byte) (map[string]interface{}, error) {
// 	tree, err := Read(b)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return conf.GetFlattenedMap(tree)
// }
