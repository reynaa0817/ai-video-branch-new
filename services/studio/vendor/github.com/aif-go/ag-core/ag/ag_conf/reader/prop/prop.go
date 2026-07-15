package prop

import (
	"github.com/magiconair/properties"
)

// Read parses []byte in the properties format into map.
func Read(b []byte) (map[string]interface{}, error) {

	p := properties.NewProperties()
	p.DisableExpansion = true
	_ = p.Load(b, properties.UTF8) // always no error

	ret := make(map[string]interface{})
	for k, v := range p.Map() {
		ret[k] = v
	}
	return ret, nil
}

// ReadFlattenedMap parses []byte in the properties format into flattened map.
// func ReadFlattenedMap(b []byte) (map[string]interface{}, error) {
// 	ret, err := Read(b)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return conf.GetFlattenedMap(ret)
// }
