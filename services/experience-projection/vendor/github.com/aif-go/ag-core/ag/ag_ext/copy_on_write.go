package ag_ext

import (
	"sync"
	"sync/atomic"
)

// AtomicValue 原子值atomic.Value的范型封装
type AtomicValue[T any] atomic.Value

func (av *AtomicValue[T]) Store(val T) {
	(*atomic.Value)(av).Store(val)
}

func (av *AtomicValue[T]) Load() T {
	var result T
	if val := (*atomic.Value)(av).Load(); val != nil {
		result = val.(T)
	}
	return result
}

// CopyOnWriteMap 线程安全的copy-on-write map实现
// 使用读写锁(RWMutex)优化读多写少场景的性能
// 读操作(Get/AsMap)使用读锁(RLock/RUnlock)，允许多个goroutine并发读取
// 写操作(Put)使用写锁(Lock/Unlock)，保证写操作的互斥性
type CopyOnWriteMap[K comparable, V any] struct {
	value AtomicValue[map[K]V] // 原子值存储map数据
	lock  sync.RWMutex         // 读写锁保护并发访问
}

func (cowm *CopyOnWriteMap[K, V]) Put(key K, value V) {
	cowm.lock.Lock()
	defer cowm.lock.Unlock()
	var current = cowm.value.Load()
	mapCopy := map[K]V{}
	for k, v := range current {
		mapCopy[k] = v
	}
	mapCopy[key] = value
	cowm.value.Store(mapCopy)
}

func (cowm *CopyOnWriteMap[K, V]) Get(key K) (V, bool) {
	cowm.lock.RLock()
	defer cowm.lock.RUnlock()
	m := cowm.value.Load()
	if m == nil {
		var zero V
		return zero, false
	}
	v, ok := m[key]
	return v, ok
}

func (cowm *CopyOnWriteMap[K, V]) AsMap() map[K]V {
	cowm.lock.RLock()
	defer cowm.lock.RUnlock()
	m := cowm.value.Load()
	if m == nil {
		return map[K]V{}
	}
	return m
}

// CopyOnWriteSlice 线程安全的copy-on-write slice实现
// 使用读写锁(RWMutex)优化读多写少场景的性能
// 读操作(Value/IndexOf)使用读锁(RLock/RUnlock)，允许多个goroutine并发读取
// 写操作(Add/AddIndex/Delete)使用写锁(Lock/Unlock)，保证写操作的互斥性
type CopyOnWriteSlice[T comparable] struct { // TODO: comparable约束可能存在限制，需论证
	value AtomicValue[[]T] // 原子值存储slice数据
	lock  sync.RWMutex     // 读写锁保护并发访问
}

func NewCopyOnWriteSlice[T comparable]() *CopyOnWriteSlice[T] {
	return &CopyOnWriteSlice[T]{
		value: AtomicValue[[]T]{},
		lock:  sync.RWMutex{},
	}
}

func (cows *CopyOnWriteSlice[T]) Value() []T {
	cows.lock.RLock()
	defer cows.lock.RUnlock()
	s := cows.value.Load()
	if s == nil {
		return []T{}
	}
	return s
}

// Add 添加元素到slice末尾
// 写操作，使用写锁保证线程安全
// 采用copy-on-write模式，创建新slice而非修改原slice
func (cows *CopyOnWriteSlice[T]) Add(toAdd T) {
	cows.lock.Lock()
	defer cows.lock.Unlock()
	currentSlice := cows.value.Load()
	newSlice := append(currentSlice, toAdd)
	cows.value.Store(newSlice)
}

// AddIndex 在指定索引位置插入元素
// 写操作，使用写锁保证线程安全
// 自动处理索引越界情况：
//   - 小于0的索引视为0
//   - 大于长度的索引视为末尾
//
// 采用copy-on-write模式，创建新slice而非修改原slice
func (cows *CopyOnWriteSlice[T]) AddIndex(index int, toAdd T) {
	cows.lock.Lock()
	defer cows.lock.Unlock()
	currentSlice := cows.value.Load()

	// 处理索引越界情况
	if index < 0 {
		index = 0
	} else if index > len(currentSlice) {
		index = len(currentSlice)
	}

	newSlice := make([]T, 0, len(currentSlice)+1)
	newSlice = append(newSlice, currentSlice[:index]...)
	newSlice = append(newSlice, toAdd)
	newSlice = append(newSlice, currentSlice[index:]...)
	cows.value.Store(newSlice)
}

// IndexOf 查找元素在slice中的位置
// 读操作，使用读锁允许多个goroutine并发读取
// 返回第一个匹配项的索引，未找到返回-1
func (cows *CopyOnWriteSlice[T]) IndexOf(target T) int {
	cows.lock.RLock()
	defer cows.lock.RUnlock()
	currentSlice := cows.value.Load()
	for i, v := range currentSlice {
		if v == target {
			return i
		}
	}
	return -1
}

// Delete 删除slice中指定的元素
// 写操作，使用写锁保证线程安全
// 删除所有匹配的元素
// 采用copy-on-write模式，创建新slice而非修改原slice
func (cows *CopyOnWriteSlice[T]) Delete(toRemove T) {
	cows.lock.Lock()
	defer cows.lock.Unlock()
	currentSlice := cows.value.Load()
	newSlice := make([]T, 0, len(currentSlice))
	for _, val := range currentSlice {
		if val != toRemove {
			newSlice = append(newSlice, val)
		}
	}
	cows.value.Store(newSlice)
}

func (cows *CopyOnWriteSlice[T]) Len() int {
	cows.lock.RLock()
	defer cows.lock.RUnlock()
	currentSlice := cows.value.Load()
	return len(currentSlice)
}

func (cows *CopyOnWriteSlice[T]) DeleteIndex(index int) {
	cows.lock.Lock()
	defer cows.lock.Unlock()
	currentSlice := cows.value.Load()

	// 检查索引有效性
	if index < 0 || index >= len(currentSlice) {
		return
	}

	newSlice := make([]T, 0, len(currentSlice)-1)
	newSlice = append(newSlice, currentSlice[:index]...)
	newSlice = append(newSlice, currentSlice[index+1:]...)
	cows.value.Store(newSlice)
}

func (cows *CopyOnWriteSlice[T]) Set(index int, value T) {
	cows.lock.Lock()
	defer cows.lock.Unlock()
	currentSlice := cows.value.Load()

	// 检查索引有效性
	if index < 0 || index >= len(currentSlice) {
		return
	}

	newSlice := make([]T, len(currentSlice))
	copy(newSlice, currentSlice)
	newSlice[index] = value
	cows.value.Store(newSlice)
}
