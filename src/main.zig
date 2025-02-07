const std = @import("std");
const writer = std.io.getStdOut().writer();

// Define the structure to match the JSON format
const GoVersion = struct {
    version: []const u8,
    stable: bool,
    files: []FileEntry,
};

const FileEntry = struct {
    filename: []const u8,
    os: []const u8,
    arch: []const u8,
    version: []const u8,
    sha256: []const u8,
    size: u32,
    kind: []const u8,
};
const HTTPStatusError = error{
    StatusNotOK,
};

const kernel_releases_url = "https://go.dev/dl/?mode=json";

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    const response = try get(kernel_releases_url, headers, &client, alloc);

    const parsed_json = try std.json.parseFromSlice([]GoVersion, allocator, response.items, .{});

    var latest_stable_version: ?[]const u8 = null;

    for (parsed_json.value) |go_version| {
        if (go_version.stable) {
            if (latest_stable_version == null or std.mem.order(u8, go_version.version, latest_stable_version.?) == .gt) {
                latest_stable_version = go_version.version;
            }
        }
    }

    try writer.print("Latest stable version: \x1b[31m{s}\x1b[0m\n", .{latest_stable_version orelse "No stable version found"});
}

fn get(
    url: []const u8,
    headers: []const std.http.Header,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    var response_body = std.ArrayList(u8).init(allocator);

    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response_body },
    });

    if (response.status != std.http.Status.ok) {
        try writer.print("Response Status: {d}\n", .{response.status});
        return HTTPStatusError.StatusNotOK;
    }

    return response_body;
}
