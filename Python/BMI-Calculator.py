def calculate_bmi(weight_kg: float, height_cm: float) -> float:
    """Calculate BMI using standard metric units: weight in kg, height in cm."""
    height_m = height_cm / 100.0
    return weight_kg / (height_m ** 2)

def get_bmi_category(bmi: float) -> str:
    """Determine clinical classification based on BMI score."""
    if bmi < 18.5:
        return "underweight"
    elif bmi < 25.0:
        return "normal weight"
    elif bmi < 30.0:
        return "overweight"
    elif bmi < 35.0:
        return "obese (Class I)"
    elif bmi < 40.0:
        return "severely obese (Class II)"
    else:
        return "morbidly obese (Class III)"

def main():
    print("=== Professional BMI Calculator ===")
    name = input("Enter your name: ").strip()
    
    # Robust error handling for user inputs
    try:
        height_cm = float(input("Enter your height in cm: "))
        weight_kg = float(input("Enter your weight in kg: "))
        
        if height_cm <= 0 or weight_kg <= 0:
            print("Error: Height and weight must be positive values.")
            return
            
        bmi = calculate_bmi(weight_kg, height_cm)
        category = get_bmi_category(bmi)
        
        print(f"\n--- Results for {name} ---")
        print(f"Height: {height_cm} cm")
        print(f"Weight: {weight_kg} kg")
        print(f"BMI Score: {bmi:.2f}")
        print(f"Status: You are classified as {category}.")
        
    except ValueError:
        print("Invalid input. Please enter valid numeric values for height and weight.")

if __name__ == "__main__":
    main()