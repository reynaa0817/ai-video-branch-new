package ag_conf

// IPropertySource 属性源接口
type IPropertySource interface {
	GetName() string
	EqualsName(psname string) bool
	GetSource() map[string]any
	GetProperty(key string) any
	ContainsProperty(key string) bool
	GetPropertyNames() []string
}
