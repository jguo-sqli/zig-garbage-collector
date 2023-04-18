const std = @import("std");
const print = @import("std").debug.print;
const VM = @import("garbage_collector.zig").VM;

test "Test 1: Objects on stack are preserved" {
    const allocator = std.testing.allocator;
    print("Objects on stack are prserved.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);
    vm.gc();

    try std.testing.expect(vm.num_objects == 2);
    vm.deinit();
}

test "Test 2: Unreached objects are collected" {
    const allocator = std.testing.allocator;
    print("Unreached objects are collected.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);
    _ = vm.pop();
    _ = vm.pop();
    vm.gc();

    // "Should have collected objects."
    try std.testing.expect(vm.num_objects == 0);
    vm.deinit();
}

test "Test 3: Reach nested objects" {
    const allocator = std.testing.allocator;
    print("Reach nested objects.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);
    _ = try vm.pushPair();
    try vm.pushInt(3);
    try vm.pushInt(4);
    _ = try vm.pushPair();
    _ = try vm.pushPair();

    vm.gc();
    try std.testing.expect(vm.num_objects == 7);
    vm.deinit();
}

test "Test 4: Handle cycles" {
    const allocator = std.testing.allocator;
    print("Handle cycles.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);
    var a = vm.pushPair() catch unreachable;
    try vm.pushInt(3);
    try vm.pushInt(4);
    var b = vm.pushPair() catch unreachable;

    // Set up a cycle, and also make 2 and 4 unreachable and collectible
    a.data.pair.tail = b;
    b.data.pair.tail = a;

    vm.gc();
    try std.testing.expect(vm.num_objects == 4);
    vm.deinit();
}

test "Test 5: Performance test" {
    const allocator = std.testing.allocator;
    print("Performance Test.\n", .{});
    var vm = &(try VM.init(allocator));

    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        var j: i32 = 0;
        while (j < 20) : (j += 1) {
            try vm.pushInt(i);
        }
        var k: i32 = 0;
        while (k < 20) : (k += 1) {
            _ = try vm.pop();
        }
    }
    vm.deinit();
}
