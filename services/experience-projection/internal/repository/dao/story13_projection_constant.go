package dao
// Story13ProjectionNamingSqlMap 命名SQL映射
var Story13ProjectionNamingSqlMap = map[string]string{}

// excludeStory13ProjectionZeroColNames 插入忽略空值时标记哪些字段需要排除在外
var excludeStory13ProjectionZeroColNames = map[string]int{"ProjectedAt": 0}
