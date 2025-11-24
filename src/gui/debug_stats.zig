const std = @import("std");
const gl = @import("c.zig").glad;
const checkGlError = @import("renderers/opengl.zig").checkGlError;

const AVERAGE_FRAMES = 60;

pub const DebugStats = struct {
    // GPU timer queries
    query_ids: [2]u32,
    current_query_idx: usize,
    query_active: bool,
    frame_count: u32,

    // Timing data
    fps: f64,
    cpu_time_ms: f64,
    gpu_time_ms: f64,
    last_time: f64,

    // Smoothing (running average over N frames)
    cpu_samples: [AVERAGE_FRAMES]f64,
    gpu_samples: [AVERAGE_FRAMES]f64,
    sample_idx: usize,
    samples_filled: bool,

    pub fn init() DebugStats {
        var self = DebugStats{
            .query_ids = [_]u32{ 0, 0 },
            .current_query_idx = 0,
            .query_active = false,
            .frame_count = 0,
            .fps = 0.0,
            .cpu_time_ms = 0.0,
            .gpu_time_ms = 0.0,
            .last_time = 0.0,
            .cpu_samples = [_]f64{0.0} ** AVERAGE_FRAMES,
            .gpu_samples = [_]f64{0.0} ** AVERAGE_FRAMES,
            .sample_idx = 0,
            .samples_filled = false,
        };

        // Create GPU timer queries
        gl.glGenQueries(2, &self.query_ids);
        checkGlError("glGenQueries");

        return self;
    }

    pub fn deinit(self: *DebugStats) void {
        gl.glDeleteQueries(2, &self.query_ids);
    }

    pub fn beginFrame(self: *DebugStats, current_time: f64) void {
        if (self.last_time > 0.0) {
            const delta_time = current_time - self.last_time;
            self.fps = 1.0 / delta_time;

            const cpu_ms = delta_time * 1000.0;
            self.cpu_samples[self.sample_idx] = cpu_ms;

            self.cpu_time_ms = self.getAverage(self.cpu_samples[0..]);
        }
        self.last_time = current_time;

        if (!self.query_active) {
            gl.glBeginQuery(gl.GL_TIME_ELAPSED, self.query_ids[self.current_query_idx]);
            checkGlError("glBeginQuery");
            self.query_active = true;
        }
    }

    pub fn endFrame(self: *DebugStats) void {
        if (self.query_active) {
            gl.glEndQuery(gl.GL_TIME_ELAPSED);
            checkGlError("glEndQuery");
            self.query_active = false;
        }

        self.frame_count += 1;

        if (self.frame_count > 1) {
            const prev_query_idx = (self.current_query_idx + 1) % 2;
            var available: i32 = 0;
            gl.glGetQueryObjectiv(self.query_ids[prev_query_idx], gl.GL_QUERY_RESULT_AVAILABLE, &available);
            checkGlError("glGetQueryObjectiv");

            if (available != 0) {
                var gpu_time_ns: u64 = 0;
                gl.glGetQueryObjectui64v(self.query_ids[prev_query_idx], gl.GL_QUERY_RESULT, &gpu_time_ns);
                checkGlError("glGetQueryObjectui64v");

                const gpu_ms = @as(f64, @floatFromInt(gpu_time_ns)) / 1_000_000.0;
                self.gpu_samples[self.sample_idx] = gpu_ms;

                self.gpu_time_ms = self.getAverage(self.gpu_samples[0..]);
            }
        }

        self.sample_idx = (self.sample_idx + 1) % AVERAGE_FRAMES;
        if (self.sample_idx == 0) {
            self.samples_filled = true;
        }

        self.current_query_idx = (self.current_query_idx + 1) % 2;
    }

    fn getAverage(self: *const DebugStats, samples: []const f64) f64 {
        const count = if (self.samples_filled) AVERAGE_FRAMES else @max(1, self.sample_idx);
        var sum: f64 = 0.0;
        for (0..count) |i| {
            sum += samples[i];
        }
        return sum / @as(f64, @floatFromInt(count));
    }

    pub fn format(self: *const DebugStats, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "FPS: {d:.0} | CPU: {d:.2}ms | GPU: {d:.2}ms", .{ self.fps, self.cpu_time_ms, self.gpu_time_ms });
    }
};
