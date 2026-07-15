package dao

// Story13FactNamingSqlMap 命名SQL映射
var Story13FactNamingSqlMap = map[string]string{}

// excludeStory13FactZeroColNames 插入忽略空值时标记哪些字段需要排除在外
var excludeStory13FactZeroColNames = map[string]int{"CreatedAt": 0}
