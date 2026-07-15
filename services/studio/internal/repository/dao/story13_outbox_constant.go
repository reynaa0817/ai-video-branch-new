package dao
// Story13OutboxNamingSqlMap 命名SQL映射
var Story13OutboxNamingSqlMap = map[string]string{}

// excludeStory13OutboxZeroColNames 插入忽略空值时标记哪些字段需要排除在外
var excludeStory13OutboxZeroColNames = map[string]int{"CreatedAt": 0}
