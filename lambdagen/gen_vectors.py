# lambda1 = (y2-y3) * x2 + (x3-x2)*y2 / area
# lambda2 = (y1-y2)*x1 + (x2-x1)*y1 / area

# z = lambda1*z1 + lambda2*z3 + (1-lambda2-lambda3)*z2

# dl1x = (y3-y2) / area
# dl2x = (y2-y1) / area

# dl1y = (x3-x2) / area
# dl2y = (x2-x1) / area

# dzx = dl1x*z1 + dl2x*z3 - (dl1x + dl2x)*z2
# dzy = dl1y*z1 + dl2y*z3 - (dl1y + dl2y)*z2

# lambda2 and lambda3 were swapped in the testbench and the RTL

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

def float_to_fixed_point_hex(f, frac_bits=16):
    scaler = 2.0**frac_bits
    fixed_point_val = int(round(f * scaler))
    masked_val = fixed_point_val & 0xFFFFFFFF
    return f"{masked_val:08x}"

def main():
    NVECS = 5
    all_results = []
    all_z = []
    all_derivatives = []
    
    with open("vectors.mem", "w") as f_vec:
        for tID in range(NVECS):
            x1, y1 = random.randint(0, 100), random.randint(0, 100)
            x2, y2 = random.randint(0, 100), random.randint(0, 100)
            x3, y3 = random.randint(0, 100), random.randint(0, 100)
            z1, z2, z3 = [random.randint(-4, 3) for _ in range(3)]

            area = (y2 - y3) * x1 + (y3 - y1) * x2 + (y1 - y2) * x3
            
            lambda1 = ((y2 - y3) * x2 + (x3 - x2) * y2) / area
            lambda2 = ((y1 - y2) * x1 + (x2 - x1) * y1) / area
            lambda3 = 1 - lambda1 - lambda2
            
            z_expected = lambda1 * z1 + lambda2 * z3 + lambda3 * z2
            
            dl1x = (y3 - y2) / area
            dl2x = (y2 - y1) / area
            
            dl1y = (x2 - x3) / area
            dl2y = (x1 - x2) / area
            
            dzx = dl1x * z1 + dl2x * z3 - (dl1x + dl2x) * z2
            dzy = dl1y * z1 + dl2y * z3 - (dl1y + dl2y) * z2

            all_results.append((lambda1, lambda2, lambda3))
            all_z.append(z_expected)
            all_derivatives.append((dl1x, dl2x, dl1y, dl2y, dzx, dzy))

            f_vec.write(f"{pack_input(tID, x1, x2, x3, y1, y2, y3, z1, z2, z3):032x}\n")

    for i, name in enumerate(["l1", "l2", "l3"]):
        with open(f"expected_{name}.mem", "w") as f:
            for result in all_results:
                f.write(f"{float_to_fixed_point_hex(result[i])}\n")

    with open("expected_z.mem", "w") as f:
        for z_val in all_z:
            f.write(f"{float_to_fixed_point_hex(z_val)}\n")
    
    derivative_names = ["dl1x", "dl2x", "dl1y", "dl2y", "dzx", "dzy"]
    for i, name in enumerate(derivative_names):
        with open(f"expected_{name}.mem", "w") as f:
            for derivs in all_derivatives:
                f.write(f"{float_to_fixed_point_hex(derivs[i])}\n")

if __name__ == "__main__":
    main()