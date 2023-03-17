function to_quaternion(pitch::Real, roll::Real, yaw::Real)
    t0 = cos(yaw * 0.5)
    t1 = sin(yaw * 0.5)
    t2 = cos(roll * 0.5)
    t3 = sin(roll * 0.5)
    t4 = cos(pitch * 0.5)
    t5 = sin(pitch * 0.5)

    w_val = t0 * t2 * t4 + t1 * t3 * t5
    x_val = t0 * t3 * t4 - t1 * t2 * t5
    y_val = t0 * t2 * t5 + t1 * t3 * t4
    z_val = t1 * t2 * t4 - t0 * t3 * t5
    return Quaternionr(x_val, y_val, z_val, w_val)
end
