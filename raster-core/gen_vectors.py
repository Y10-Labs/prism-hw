import random

def pack_input(tID, x1, x2, x3, y1, y2, y3, z1, z2, z3):
    return ((tID & 0xFFFF) << 112) | \
           ((z1 & 0xFFFF) << 96)  | \
           ((y1 & 0xFF)   << 80)  | \
           ((y2 & 0xFF)   << 72)  | \
           ((y3 & 0xFF)   << 64)  | \
           ((x1 & 0x1FF)  << 50)  | \
           ((x2 & 0x1FF)  << 41)  | \
           ((x3 & 0x1FF)  << 32)  | \
           ((z2 & 0xFFFF) << 16)  | \
           (z3 & 0xFFFF)

def compute_lambdas(xA, yA, xB, yB, xC, yC, xD, yD):
    denom1 = (yA - yC) * (xB - xC) - (xA - xC) * (yB - yC)
    if denom1 == 0:
        l1 = 0.0
    else:
        l1 = ((yD - yC) * (xB - xC) - (xD - xC) * (yB - yC)) / float(denom1)
    denom2 = (yB - yA) * (xC - xA) - (xB - xA) * (yC - yA)
    if denom2 == 0:
        l2 = 0.0
    else:
        l2 = ((yD - yA) * (xC - xA) - (xD - xA) * (yC - yA)) / float(denom2)
    return l1, l2, 1.0 - l1 - l2

def float_to_fixed_point_hex(f, frac_bits=8):
    scaler = 2.0**frac_bits
    fixed_point_val = int(round(f * scaler))
    masked_val = fixed_point_val & 0xFFFFFFFF
    return f"{masked_val:08x}"

def main():
    NVECS = 5
    print(f"Generating {NVECS} test vectors and expected lambdas (24.8 fixed-point)...\n")
    all_results = []
    all_z = []
    with open("vectors.mem", "w") as f_vec:
        for tID in range(NVECS):
            x1, y1 = random.randint(0, 400), random.randint(0, 127)
            x2, y2 = random.randint(0, 400), random.randint(0, 127)
            x3, y3 = random.randint(0, 400), random.randint(0, 127)
            z1, z2, z3 = [random.randint(-32768, 32767) for _ in range(3)]

            l1, l2, l3 = compute_lambdas(x1, y1, x2, y2, x3, y3, 0, 0)
            z_expected = l1 * z1 + l2 * z2 + l3 * z3

            all_results.append((l1, l2, l3))
            all_z.append(z_expected)

            print(f"Case {tID}: A=({x1},{y1},{z1}) B=({x2},{y2},{z2}) C=({x3},{y3},{z3}) D=(0,0,0)")
            print(f"  z1={z1} z2={z2} z3={z3}")
            print(f"  Float Lambdas:  λ1={l1:.6f} λ2={l2:.6f} λ3={l3:.6f}")
            print(f"  Expected z: {z_expected:.6f}")
            print(f"  Fixed-Point Hex: λ1=0x{float_to_fixed_point_hex(l1)} "
                  f"λ2=0x{float_to_fixed_point_hex(l2)} "
                  f"λ3=0x{float_to_fixed_point_hex(l3)} "
                  f"z=0x{float_to_fixed_point_hex(z_expected)}\n")

            f_vec.write(f"{pack_input(tID, x1, x2, x3, y1, y2, y3, z1, z2, z3):032x}\n")

    # write expected lambdas
    for i, name in enumerate(["l1", "l2", "l3"]):
        with open(f"expected_{name}.mem", "w") as f:
            for result in all_results:
                f.write(f"{float_to_fixed_point_hex(result[i])}\n")

    # write expected z
    with open("expected_z.mem", "w") as f:
        for z_val in all_z:
            f.write(f"{float_to_fixed_point_hex(z_val)}\n")

    print("Successfully generated files: vectors.mem, expected_l1.mem, expected_l2.mem, expected_l3.mem, expected_z.mem")

if __name__ == "__main__":
    main()
