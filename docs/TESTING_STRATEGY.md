# ROADIX — Quality Assurance & Testing Strategy

**Status:** DRAFT BASELINE (To be finalized in Phase 2)  
**Testing Framework:** `flutter_test`, `integration_test`, `mocktail` / `mockito`  

---

## 1. Testing Pyramid for ROADIX

```text
       /\
      /  \      E2E Integration Tests (Full Request -> Dispatch -> Quote -> Complete)
     /----\     
    /      \    Widget & Golden Tests (Triage flow, SOS timer, Modal sheets)
   /--------\   
  /          \  Unit Tests (Domain entities, validation, dispatch scoring math, mappers)
 /------------\
```

---

## 2. Test Suites by Layer

1. **Unit Tests:**
   - Pure domain entity serialization / deserialization.
   - Dispatch matching algorithm: test weights ($P, E, T, A$), edge cases (0 distance, no rating).
   - Validation rules: phone numbers (BD format `+880`), vehicle plates, positive quotation fees.
2. **Widget Tests:**
   - Wizard navigation preserving state.
   - SOS Screen 5-second countdown & cancel behavior.
   - Quotation approve/reject user interactions.
3. **Integration & Concurrency Tests:**
   - Dispatch candidate race condition: two mechanics accepting same offer simultaneously.
   - Network failure & offline request restoration.
   - Supabase RLS policy penetration testing: verify that User A cannot read User B's vehicle or wallet records.
