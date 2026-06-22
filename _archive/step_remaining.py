
import sys
sys.stdout.reconfigure(encoding="utf-8")

path = "accident-report.html"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

changes = 0

# 1. Add persons collection before payload
old = "const registryId = null;

            const payload = {"
new = "const registryId = null;

            // Collect all injured persons
            const persons = [];
            document.querySelectorAll(\"#injuredPersonsContainer .person-entry\").forEach((entry, idx) => {
                const p = {
                    full_name: entry.querySelector(\"[data-person-field='full_name']\")?.value?.trim() || null,
                    age_years: entry.querySelector(\"[data-person-field='age_years']\")?.value ? parseInt(entry.querySelector(\"[data-person-field='age_years']\").value) : null,
                    sex: entry.querySelector(\"[data-person-field='sex']\")?.value || null,
                    id_number: (entry.querySelector(\"[data-person-field='id_number']\")?.value || \"\").toUpperCase(),
                    occupation_at_accident: entry.querySelector(\"[data-person-field='occupation_at_accident']\")?.value?.trim() || null,
                    usual_occupation: entry.querySelector(\"[data-person-field='usual_occupation']\")?.value?.trim() || null,
                    experience_level: entry.querySelector(\"[data-person-field='experience_level']\")?.value?.trim() || null,
                    email: entry.querySelector(\"[data-person-field='email']\")?.value?.trim() || null,
                    injury_fatal: entry.querySelector(\"[data-person-field='injury_fatal']\")?.value || null,
                    disabled_three_days: entry.querySelector(\"[data-person-field='disabled_three_days']\")?.value || null,
                    hourly_pay: entry.querySelector(\"[data-person-field='hourly_pay']\")?.value ? parseFloat(entry.querySelector(\"[data-person-field='hourly_pay']\").value) : null,
                    medical_practitioner: entry.querySelector(\"[data-person-field='medical_practitioner']\")?.value?.trim() || null,
                    sort_order: idx
                };
                persons.push(p);
            });

            const payload = {"
if old in content:
    content = content.replace(old, new)
    changes += 1
    print("1. Added persons collection")
else:
    print("1. NOT FOUND: registry null + payload")

# 2. Update insert
old2 = """            const { data: insertedReport, error } = await window.supabaseClient.from('accident_reports')
                .insert([payload])
                .select('id')
                .single();"""
new2 = """            const { data: insertedReport, error } = await window.supabaseClient.from('accident_reports')
                .insert([payload])
                .select('id')
                .single();
            if (error) throw error;
            if (persons.length > 0) {
                const personRecords = persons.map(p => ({...p, accident_report_id: insertedReport.id}));
                const { error: personsError } = await window.supabaseClient.from('accident_injured_persons').insert(personRecords);
                if (personsError) throw personsError;
            }"""
if old2 in content:
    content = content.replace(old2, new2)
    changes += 1
    print("2. Updated insert")
else:
    print("2. NOT FOUND: old insert")

# 3. Update draft
old3 = """            const draftId = await createClaimDraftFromAccident(
                payload,
                insertedReport.id,
                userResult.user.id,
                registryId
            );"""
new3 = """            const firstPerson = persons.length > 0 ? persons[0] : null;
            const draftPayload = firstPerson ? {...payload, injured_name: firstPerson.full_name, injured_age: firstPerson.age_years, injured_sex: firstPerson.sex, injured_id_number: firstPerson.id_number, occupation_at_accident: firstPerson.occupation_at_accident, usual_occupation: firstPerson.usual_occupation, experience_level: firstPerson.experience_level, injury_fatal: firstPerson.injury_fatal, disabled_three_days: firstPerson.disabled_three_days, hourly_pay: firstPerson.hourly_pay, medical_practitioner: firstPerson.medical_practitioner} : payload;
            const draftId = await createClaimDraftFromAccident(draftPayload, insertedReport.id, userResult.user.id, null);"""
if old3 in content:
    content = content.replace(old3, new3)
    changes += 1
    print("3. Updated draft")
else:
    print("3. NOT FOUND: old draft")

if changes > 0:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Done! {changes} changes made")
else:
    print("No changes made")
