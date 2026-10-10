// Clip both character color sheets against the actual water silhouette.
// World-space edges also handle translated, scaled and rotated pools.
uniform int water_pool_count = 0;
uniform int water_edge_counts[4];
uniform vec4 water_edges[32];
bool submerged_pixel(vec2 point) {
    int offset = 0;
    for (int pool = 0; pool < 4; pool++) {
        if (pool >= water_pool_count) { break; }
        bool inside = false;
        for (int edge = 0; edge < 8; edge++) {
            if (edge >= water_edge_counts[pool]) { break; }
            vec4 segment = water_edges[offset + edge];
            vec2 a = segment.xy;
            vec2 b = segment.zw;
            if ((a.y > point.y) != (b.y > point.y)) {
                float crossing = a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y);
                if (point.x < crossing) { inside = !inside; }
            }
        }
        if (inside) { return true; }
        offset += water_edge_counts[pool];
    }
    return false;
}
