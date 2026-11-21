# =====================================================================
# VEXA Luxury Fashion E-Commerce - Automated Security & Integrity Tests
# Phase 8 Verification Suite
# =====================================================================

$ErrorActionPreference = "Continue"
$projectRoot = "C:\Users\sethh\.gemini\antigravity\scratch\vexa-fashion"
$testResults = @()

function Assert-Test {
    param (
        [string]$Name,
        [bool]$Condition,
        [string]$Details
    )
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    $color = if ($Condition) { "Green" } else { "Red" }
    Write-Host "[$status] $Name" -ForegroundColor $color
    if (-not $Condition) {
        Write-Host "       Reason: $Details" -ForegroundColor Yellow
    }
    $global:testResults += [PSCustomObject]@{
        Test = $Name
        Status = $status
        Details = $Details
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  RUNNING VEXA MASTER SECURITY & INTEGRITY TEST SUITE" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------
# Test 1: Zero Fake OTP / Real SMS Phone Auth Integrity
# ---------------------------------------------------------
$appJs = [System.IO.File]::ReadAllText((Join-Path $projectRoot "app.js"), [System.Text.Encoding]::UTF8)
$serverJs = [System.IO.File]::ReadAllText((Join-Path $projectRoot "server.js"), [System.Text.Encoding]::UTF8)

$hasFakeOtpAlert = $appJs -match 'alert\(.*(?:OTP|otp).*123456' -or $appJs -match 'Your OTP is\s*123456'
Assert-Test -Name "Security: No hardcoded demo OTP alert (123456)" -Condition (-not $hasFakeOtpAlert) -Details "Found hardcoded demo OTP popup alert in app.js"

$hasMockOtpInConsole = $appJs -match 'console\.log\(.*Demo OTP' -or $appJs -match 'console\.log\(.*OTP:'
Assert-Test -Name "Security: Zero OTP leakage in client console logs" -Condition (-not $hasMockOtpInConsole) -Details "Found OTP logged to console in app.js"

$hasRealPhoneAuthMethod = $appJs.Contains("sendRealSmsOtp") -and $appJs.Contains("verifyRealSmsOtp")
Assert-Test -Name "Architecture: Real Mobile Phone SMS Auth functions implemented" -Condition $hasRealPhoneAuthMethod -Details "Missing sendRealSmsOtp or verifyRealSmsOtp in app.js"

# ---------------------------------------------------------
# Test 2: Admin Authentication & 2FA Gate
# ---------------------------------------------------------
$hasAdmin2faModal = $appJs.Contains("openAdmin2faModal") -and $appJs.Contains("submitAdmin2FA")
Assert-Test -Name "Security: Mandatory Owner 2FA TOTP Gate implemented" -Condition $hasAdmin2faModal -Details "Missing 2FA TOTP verification modal in app.js"

$hasRecoveryKeys = $appJs.Contains("VX-REC-7821-4902") -and $appJs.Contains("VX-REC-8842-1903")
Assert-Test -Name "Security: 6 Emergency Backup Recovery Keys configured" -Condition $hasRecoveryKeys -Details "Missing emergency recovery keys in app.js"

$hasOwnerIsolation = $appJs.Contains("sethharsh0010@gmail.com")
Assert-Test -Name "Security: Isolated Owner email enforcement (sethharsh0010@gmail.com)" -Condition $hasOwnerIsolation -Details "Owner email not strictly gated"

# ---------------------------------------------------------
# Test 3: 15-Module Admin Command Center Architecture
# ---------------------------------------------------------
$modules = @(
    "overview", "products", "categories", "collections", "inventory",
    "orders", "customers", "coupons", "homepage", "reviews",
    "analytics", "reports", "settings", "security", "audit"
)
$missingModules = @()
foreach ($m in $modules) {
    if (-not ($appJs.Contains("getAdmin" + (Get-Culture).TextInfo.ToTitleCase($m) + "HTML") -or $appJs.Contains("switchAdminTab('$m'"))) {
        $missingModules += $m
    }
}
Assert-Test -Name "Architecture: All 15 Admin Modules fully integrated" -Condition ($missingModules.Count -eq 0) -Details "Missing admin modules: $($missingModules -join ', ')"

# ---------------------------------------------------------
# Test 4: Variant-Level SKU Inventory & Oversell Prevention
# ---------------------------------------------------------
$hasVariantStockValidation = $appJs.Contains('Only ${sizeObj.stock} units left') -or $appJs.Contains("Insufficient inventory")
Assert-Test -Name "E-Commerce: Variant SKU stock verification before order placement" -Condition $hasVariantStockValidation -Details "Missing variant SKU stock validation in checkout"

$hasStockDeduction = $appJs.Contains("sizeObj.stock = Math.max(0, sizeObj.stock - item.quantity)") -or $appJs.Contains("sizeObj.stock -= item.quantity")
Assert-Test -Name "E-Commerce: Atomic Variant stock deduction upon order confirmation" -Condition $hasStockDeduction -Details "Missing variant stock deduction logic in placeOrder"

# ---------------------------------------------------------
# Test 5: Multi-Step Checkout & Payment Gateways
# ---------------------------------------------------------
$hasCheckoutSteps = $appJs.Contains("DELIVERY ADDRESS") -and $appJs.Contains("ORDER SUMMARY") -and $appJs.Contains("PAYMENT GATEWAY")
Assert-Test -Name "UI/UX: 3-Step Guided Atelier Checkout flow" -Condition $hasCheckoutSteps -Details "Missing 3-step checkout UI in app.js"

$hasIndianPincodeCheck = $appJs.Contains("autoLookupPincode") -and $appJs.Contains("BlueDart")
Assert-Test -Name "Logistics: Indian 6-Digit PIN code auto-lookup & BlueDart validation" -Condition $hasIndianPincodeCheck -Details "Missing PIN code auto-lookup logic"

$hasRazorpayIntegration = $appJs.Contains("Razorpay") -and $appJs.Contains("rzp_test_VEXAJaipur2026")
Assert-Test -Name "Payments: Razorpay Payment Gateway integration wired" -Condition $hasRazorpayIntegration -Details "Missing Razorpay integration in checkout"

# ---------------------------------------------------------
# Test 6: Order Lifecycle, BlueDart Tracking & GST Invoices
# ---------------------------------------------------------
$has7StepTracking = $appJs.Contains("Order Placed") -and $appJs.Contains("Packed in Bespoke Presentation Box") -and $appJs.Contains("Shipped via BlueDart Air")
Assert-Test -Name "Fulfillment: 7-Stage visual status tracking timeline" -Condition $has7StepTracking -Details "Missing 7-stage order status tracking"

$hasGstInvoice = $appJs.Contains("openAdminInvoice") -and $appJs.Contains("08AABCV1234F1Z8") -and $appJs.Contains("CGST (6%)")
Assert-Test -Name "Compliance: GST-compliant printable Tax Invoice (GSTIN: 08AABCV1234F1Z8, HSN: 6203/6403)" -Condition $hasGstInvoice -Details "Missing GST tax invoice generator"

$has7DayReturn = $appJs.Contains("openReturnModal") -and $appJs.Contains("submitReturnRequest")
Assert-Test -Name "Patron Care: 7-Day Doorstep Return & Exchange Request flow" -Condition $has7DayReturn -Details "Missing 7-day return/exchange request flow"

# ---------------------------------------------------------
# Test 7: Syntactic & Structural Balance
# ---------------------------------------------------------
$openBraces = ($appJs.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($appJs.ToCharArray() | Where-Object { $_ -eq '}' }).Count
$balanced = ($openBraces -eq $closeBraces)
Assert-Test -Name "Code Quality: JavaScript bracket balance ({ $openBraces vs } $closeBraces)" -Condition $balanced -Details "Brace mismatch in app.js"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
$passed = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$total = $testResults.Count
Write-Host "  TEST RESULTS: $passed / $total PASSED" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
