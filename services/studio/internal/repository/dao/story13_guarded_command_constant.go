package dao

// Story13GuardedCommandNamingSqlMap 命名SQL映射
var Story13GuardedCommandNamingSqlMap = map[string]string{}

// excludeStory13GuardedCommandZeroColNames 插入忽略空值时标记哪些字段需要排除在外
var excludeStory13GuardedCommandZeroColNames = map[string]int{"CreatedAt": 0}
