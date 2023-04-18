//! Jack Guo, 2023
//! Implementation of a simple mark-sweep garbage collector. Ported from Bob Bystorms' orginal code in C
//! https://journal.stuffwithstuff.com/2013/12/08/babys-first-garbage-collector/
//!

const std = @import("std");
const print = @import("std").debug.print;

const STACK_MAX = 256;
const INIT_OBJ_NUM_MAX = 8;

// All types of objects that are supported by the VM/Garbage Collector
const GC_OBJECT_TYPE = enum {
    int,
    pair,
};

// Object stores data for an individual object used by our GC
const GC_OBJECT = struct {
    // Type of Object
    type: GC_OBJECT_TYPE,
    // Flag indicating whether the object is being used
    marked: bool,
    //Actual data maintained by the object
    data: union { value: i32, pair: struct { head: ?*GC_OBJECT, tail: ?*GC_OBJECT } },
    // The next object in the linked list of heap allocated objects
    next: ?*GC_OBJECT,
};

// A small virtual machine
pub const VM = struct {
    // Stack used to store objects between VM function calls
    // These objects serve as the roots of the GC
    stack: []*GC_OBJECT,

    // Number of objects currently on the stack
    stack_size: u32,

    // First object in the linked list of all objects on the heap
    first_object: ?*GC_OBJECT,

    // The total number of currently allocated objects
    num_objects: u32,

    // The number of objects required to trigger a GC
    max_objects: u32,

    // Allocator that will be used to manage the VM's memory
    allocator: std.mem.Allocator,

    // Constructor
    pub fn init(alloc: std.mem.Allocator) !VM {
        const stack: []*GC_OBJECT = try alloc.alloc(*GC_OBJECT, STACK_MAX);
        return VM{
            .stack = stack,
            .stack_size = 0,
            .first_object = null,
            .num_objects = 0,
            .max_objects = STACK_MAX,
            .allocator = alloc,
        };
    }

    // Reclaim all memory allocated by the GC
    pub fn deinit(self: *VM) void {
        // Removes all GC roots
        self.stack_size = 0;
        self.gc();
        self.allocator.free(self.stack);
    }

    // Mark will flag an object as being in-use. Unused objects are freed at the end of the GC cycle
    fn mark(self: *VM, object: *GC_OBJECT) void {
        // If already marked, we're done.
        // Check this first to avoid recursing on cycles in the object graph.
        if (object.marked) return;

        object.marked = true;
        if (object.type == GC_OBJECT_TYPE.pair) {
            if (object.data.pair.head) |head| {
                self.mark(head);
            }
            if (object.data.pair.tail) |tail| {
                self.mark(tail);
            }
        }
    }

    // Mark all objects currently in use by the VM
    fn markAll(self: *VM) void {
        var i: u32 = 0;
        while (i < self.stack_size) : (i += 1) {
            self.mark(self.stack[i]);
        }
    }

    // Free unused memory
    fn sweep(self: *VM) void {
        var object = &(self.first_object);
        while (object.*) |obj| {
            if (!obj.marked) {
                // This object wasn't reached, so remove it from the list and free it.
                var unreached = obj;
                object.* = obj.next;
                self.allocator.destroy(unreached);
                self.num_objects -= 1;
            } else {
                // this object was reached,
                // so unmark it for the next GC cycle
                // and move on to the next object
                obj.marked = false;
                object = &(obj.next);
            }
        }
        //print("Done with sweep", .{})
    }

    // Initiate a gargabe collection cycle
    pub fn gc(self: *VM) void {
        var num_objects = self.num_objects;
        self.markAll();
        self.sweep();

        if (self.num_objects == 0) {
            self.max_objects = INIT_OBJ_NUM_MAX;
        } else {
            self.max_objects *= 2;
        }
        print("Collected {} objects, {} remaining.\n", .{ num_objects - self.num_objects, self.num_objects });
    }

    // Internal function to create a new object
    fn newObject(self: *VM, otype: GC_OBJECT_TYPE) !*GC_OBJECT {
        var obj = try self.allocator.create(GC_OBJECT);
        obj.type = otype;
        obj.marked = false;
        obj.next = self.first_object;
        self.first_object = obj;
        self.num_objects += 1;
        return obj;
    }

    // Add an integer to the stack
    pub fn pushInt(self: *VM, value: i32) !void {
        var obj = try self.newObject(GC_OBJECT_TYPE.int);
        obj.data = .{ .value = value };
        self.push(obj);
    }

    // Box top two objects on the stack into a pair
    pub fn pushPair(self: *VM) !*GC_OBJECT {
        var obj = try self.newObject(GC_OBJECT_TYPE.pair);
        var t = self.pop();
        var h = self.pop();
        obj.data = .{ .pair = .{ .head = h, .tail = t } };
        self.push(obj);
        return obj;
    }

    // Add an object to the top of the stack
    pub fn push(self: *VM, value: *GC_OBJECT) void {
        if (self.stack_size >= STACK_MAX) {
            print("Stack overflow!", .{});
            unreachable;
        }

        self.stack[self.stack_size] = value;
        self.stack_size += 1;
    }

    //Remove top object from the stack
    pub fn pop(self: *VM) *GC_OBJECT {
        if (self.stack_size == 0) {
            print("Stack underflow!", .{});
            unreachable;
        }

        self.stack_size -= 1;
        return self.stack[self.stack_size];
    }
};
