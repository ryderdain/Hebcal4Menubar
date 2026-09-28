# Davening rules

The **Davening** section of the menu shows the changes to the prayers for the Hebrew day on the menu. `DaveningRules.swift` calculates these changes from the Hebrew date on your Mac. The app does not get these rules from Hebcal. The rules operate without a network connection.

This file gives the rules that `DaveningRules.swift` uses. If you change a rule, change the code and this file together. Then use `tools/verify.sh` and replace the test table at the end of this file.

## Scope

- **Nusach**: Ashkenaz, Sefard (chassidic), Chabad or Edot HaMizrach. Select the nusach in the **Nusach** submenu. The default is Ashkenaz.
- **Location**: diaspora or Israel. Select **Eretz Yisrael (Israel customs)** in the **Nusach** submenu for Israel. The default is diaspora.
- **Day**: the Hebrew day on the menu. In the sunset mode **Auto**, the Hebrew day changes at sunset.
- The rules do not include personal conditions, for example a house of mourning, a bris or a chatan.
- The rules do not include the customs of one community, for example the yahrzeit of a rebbe.

## Seasonal inserts

| Insert | Period | Nusach |
| --- | --- | --- |
| Mashiv haRuach u'morid haGeshem | From Mussaf of Shemini Atzeret (22 Tishrei) to Shacharit of the first day of Pesach (15 Nisan) | All |
| Summer form | From Mussaf of 15 Nisan to Shacharit of 22 Tishrei | Ashkenaz in the diaspora: nothing. Ashkenaz in Israel, Sefard, Chabad and Edot HaMizrach: morid haTal |
| V'ten tal u'matar livracha | Diaspora: from Maariv on the evening of 4 December (5 December when the next civil year is a leap year) to 14 Nisan. Israel: from Maariv of 7 Cheshvan to 14 Nisan | Edot HaMizrach: Barech Aleinu (winter) and Barchenu (summer) |

On the day before V'ten tal u'matar starts, the menu shows that it starts at Maariv. The menu shows V'ten tal u'matar only on weekdays.

## Day inserts

| Insert | Days |
| --- | --- |
| Ya'aleh v'yavo | Rosh Chodesh and Chol HaMoed |
| Al haNissim | The 8 days of Chanukah, and Purim (14 Adar, or 14 Adar II in a leap year). The menu does not show Shushan Purim, because only walled cities read the Megillah on 15 Adar. |
| Aneinu | Tzom Gedaliah, Asara b'Tevet, Ta'anit Esther, Shiva Asar b'Tammuz and Tisha b'Av, with the postponed dates. Ashkenaz, Sefard and Chabad: the individual says Aneinu at Mincha, and the chazan also says Aneinu at Shacharit. Edot HaMizrach: at Shacharit and Mincha. |
| Nachem | Mincha of Tisha b'Av |
| Aseret Yemei Teshuvah | 1 to 10 Tishrei: haMelech haKadosh, haMelech haMishpat, Zochreinu, Mi Chamocha, U'chtov, B'sefer Chayim and Oseh haShalom |
| Avinu Malkeinu | Ashkenaz, Sefard and Chabad: Aseret Yemei Teshuvah (not on Shabbat) and the public fasts, but not Tisha b'Av. Edot HaMizrach: Aseret Yemei Teshuvah only (not on Shabbat). |

A fast that falls on Shabbat moves. Tzom Gedaliah, Shiva Asar b'Tammuz and Tisha b'Av move to Sunday. Ta'anit Esther moves to the Thursday before (11 Adar).

## Hallel

| Hallel | Days |
| --- | --- |
| Full | Sukkot and Shemini Atzeret (diaspora: 15 to 23 Tishrei, Israel: 15 to 22 Tishrei), Chanukah, the first days of Pesach (diaspora: 15 and 16 Nisan, Israel: 15 Nisan) and Shavuot (diaspora: 6 and 7 Sivan, Israel: 6 Sivan) |
| Half | Rosh Chodesh (not Rosh Chodesh Tevet in Chanukah, which has full Hallel) and the other days of Pesach (diaspora: 17 to 22 Nisan, Israel: 16 to 21 Nisan). Edot HaMizrach says half Hallel with no beracha. |

## Tachanun

The menu shows Tachanun only on weekdays that are not Yom Tov. When there is no Tachanun on the next day, or the next day is Shabbat or Yom Tov, there is also no Tachanun at Mincha.

| Nusach | Days with no Tachanun |
| --- | --- |
| All | Rosh Chodesh, all of Nisan, Pesach Sheni (14 Iyar), Lag BaOmer (18 Iyar), 1 to 12 Sivan, Tisha b'Av, Tu b'Av (15 Av), 9 Tishrei to the end of Tishrei, Chanukah, Tu BiShvat (15 Shvat), Purim and Shushan Purim (14 and 15 Adar), and Purim Katan and Shushan Purim Katan (14 and 15 Adar I) |
| Chabad | Also 18 Elul, 19 and 20 Kislev, 10 Shvat, and 12 and 13 Tammuz |
| Edot HaMizrach | Also 13 Sivan |

## Omitted psalms

| Psalm | Days when the menu shows "Omit" |
| --- | --- |
| Lamnatzeach | Rosh Chodesh, Chanukah, Purim, Shushan Purim, Erev Pesach, Chol HaMoed, Erev Yom Kippur and Tisha b'Av |
| Mizmor l'Todah | Erev Pesach, Chol HaMoed Pesach and Erev Yom Kippur |

## Additions and counts

| Item | Rule |
| --- | --- |
| L'David Hashem Ori | From 1 Elul to Shemini Atzeret (22 Tishrei). Chabad: to Hoshana Rabbah (21 Tishrei). For Edot HaMizrach, the menu adds that many say it all year. |
| Sefirat haOmer | The count for tonight, from the evening of 16 Nisan to the evening of 5 Sivan, with the weeks and days. Ashkenaz: baOmer. Sefard, Chabad and Edot HaMizrach: laOmer. |
| Kiddush Levanah | From 3 days after the molad (Sefard, Chabad and Edot HaMizrach: 7 days) to the middle of the lunar month (14 days, 18 hours and 22⅓ minutes after the molad). In 1 to 10 Tishrei, the menu shows "after Yom Kippur". In 1 to 9 Av (10 Av when Tisha b'Av moves to Sunday), the menu shows "after Tisha b'Av". The menu shows the start time 2 days before the window opens. |
| Torah reading | From the Hebcal leyning API: Monday and Thursday, Rosh Chodesh, fasts, festivals and Shabbat |

The app calculates the molad with the formula from Dershowitz and Reingold, *Calendrical Calculations*. The molad is in Jerusalem mean time (UTC+2:20:56). The menu shows the Kiddush Levanah times in the time zone of your Mac.

## Verification

`tools/verify.sh` does two checks:

1. It gets the Hebcal holiday data for the Hebrew years 5784 to 5788, for the diaspora and for Israel. Then it compares these data with the values that the app calculates for each day: Rosh Chodesh, the fasts, Chanukah, Yom Tov, Chol HaMoed and Purim. The result on 28 September 2026 was 21,984 checks with 0 differences.
2. It writes the test table below. The table shows the menu lines for the diaspora, in the daytime of each date. The row **All** shows the lines that are the same for all 4 nusachim.

To check other years, use this command:

```bash
tools/verify.sh 5790 5794
```

## Test table

| Date | Hebrew date | Nusach | Menu lines |
| --- | --- | --- | --- |
| Mon 2026-09-28 | 17 Tishrei 5787 (Chol HaMoed Sukkot) | All | Ya'aleh v'yavo; Full Hallel; No Tachanun; Omit Lamnatzeach |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; L'David Hashem Ori |
| | | Sefard | Morid haTal; V'ten beracha; L'David Hashem Ori |
| | | Chabad | Morid haTal; V'ten beracha; L'David Hashem Ori |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); L'David Hashem Ori (many say it all year) |
| Sat 2026-10-03 | 22 Tishrei 5787 (Shemini Atzeret) | All | Mashiv haRuach u'morid haGeshem from Mussaf; Full Hallel |
| | | Ashkenaz | L'David Hashem Ori |
| | | Sefard | L'David Hashem Ori |
| | | Edot HaMizrach | L'David Hashem Ori (many say it all year) |
| Mon 2026-10-05 | 24 Tishrei 5787 (Isru Chag) | All | Mashiv haRuach u'morid haGeshem; No Tachanun |
| | | Ashkenaz | V'ten beracha |
| | | Sefard | V'ten beracha |
| | | Chabad | V'ten beracha |
| | | Edot HaMizrach | Barchenu (summer) |
| Mon 2026-10-12 | 1 Cheshvan 5787 (Rosh Chodesh Cheshvan) | All | Mashiv haRuach u'morid haGeshem; Ya'aleh v'yavo; No Tachanun; Omit Lamnatzeach |
| | | Ashkenaz | V'ten beracha; Half Hallel; Kiddush Levanah from Wed 14 Oct, 09:22 |
| | | Sefard | V'ten beracha; Half Hallel |
| | | Chabad | V'ten beracha; Half Hallel |
| | | Edot HaMizrach | Barchenu (summer); Half Hallel (no beracha) |
| Tue 2026-10-20 | 9 Cheshvan 5787 (Ordinary weekday) | All | Mashiv haRuach u'morid haGeshem; Tachanun; Kiddush Levanah until Mon 26 Oct, 02:44 |
| | | Ashkenaz | V'ten beracha |
| | | Sefard | V'ten beracha |
| | | Chabad | V'ten beracha |
| | | Edot HaMizrach | Barchenu (summer) |
| Fri 2026-12-04 | 24 Kislev 5787 (Day before tal u'matar) | All | Mashiv haRuach u'morid haGeshem; Tachanun at Shacharit only (none at Mincha) |
| | | Ashkenaz | V'ten beracha; V'ten tal u'matar livracha begins tonight at Maariv |
| | | Sefard | V'ten beracha; V'ten tal u'matar livracha begins tonight at Maariv |
| | | Chabad | V'ten beracha; V'ten tal u'matar livracha begins tonight at Maariv |
| | | Edot HaMizrach | Barchenu (summer); Barech Aleinu (winter) begins tonight at Maariv |
| Thu 2026-12-10 | 30 Kislev 5787 (Chanukah + Rosh Chodesh Tevet) | All | Mashiv haRuach u'morid haGeshem; Ya'aleh v'yavo; Al haNissim; Full Hallel; No Tachanun; Omit Lamnatzeach |
| | | Ashkenaz | V'ten tal u'matar livracha |
| | | Sefard | V'ten tal u'matar livracha |
| | | Chabad | V'ten tal u'matar livracha |
| | | Edot HaMizrach | Barech Aleinu (winter) |
| Sun 2026-12-20 | 10 Tevet 5787 (Asara b'Tevet) | All | Mashiv haRuach u'morid haGeshem; Tachanun; Kiddush Levanah until Thu 24 Dec, 04:12 |
| | | Ashkenaz | V'ten tal u'matar livracha; Aneinu (Asara b'Tevet) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Sefard | V'ten tal u'matar livracha; Aneinu (Asara b'Tevet) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Chabad | V'ten tal u'matar livracha; Aneinu (Asara b'Tevet) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Edot HaMizrach | Barech Aleinu (winter); Aneinu (Asara b'Tevet) at Shacharit and Mincha |
| Sun 2027-02-21 | 14 Adar I 5787 (Purim Katan) | All | Mashiv haRuach u'morid haGeshem; No Tachanun |
| | | Ashkenaz | V'ten tal u'matar livracha |
| | | Sefard | V'ten tal u'matar livracha |
| | | Chabad | V'ten tal u'matar livracha |
| | | Edot HaMizrach | Barech Aleinu (winter) |
| Mon 2027-03-22 | 13 Adar II 5787 (Ta'anit Esther) | All | Mashiv haRuach u'morid haGeshem; Tachanun at Shacharit only (none at Mincha) |
| | | Ashkenaz | V'ten tal u'matar livracha; Aneinu (Ta'anit Esther) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Sefard | V'ten tal u'matar livracha; Aneinu (Ta'anit Esther) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Chabad | V'ten tal u'matar livracha; Aneinu (Ta'anit Esther) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Edot HaMizrach | Barech Aleinu (winter); Aneinu (Ta'anit Esther) at Shacharit and Mincha |
| Tue 2027-03-23 | 14 Adar II 5787 (Purim) | All | Mashiv haRuach u'morid haGeshem; Al haNissim; No Tachanun; Omit Lamnatzeach |
| | | Ashkenaz | V'ten tal u'matar livracha |
| | | Sefard | V'ten tal u'matar livracha |
| | | Chabad | V'ten tal u'matar livracha |
| | | Edot HaMizrach | Barech Aleinu (winter) |
| Wed 2027-04-21 | 14 Nisan 5787 (Erev Pesach) | All | Mashiv haRuach u'morid haGeshem; No Tachanun; Omit Lamnatzeach; Omit Mizmor l'Todah |
| | | Ashkenaz | V'ten tal u'matar livracha |
| | | Sefard | V'ten tal u'matar livracha |
| | | Chabad | V'ten tal u'matar livracha |
| | | Edot HaMizrach | Barech Aleinu (winter) |
| Thu 2027-04-22 | 15 Nisan 5787 (Pesach I) | All | Full Hallel |
| | | Ashkenaz | Summer: no morid haTal from Mussaf; Sefirat haOmer tonight: 1 day baOmer |
| | | Sefard | Morid haTal from Mussaf; Sefirat haOmer tonight: 1 day laOmer |
| | | Chabad | Morid haTal from Mussaf; Sefirat haOmer tonight: 1 day laOmer |
| | | Edot HaMizrach | Morid haTal from Mussaf; Sefirat haOmer tonight: 1 day laOmer |
| Sun 2027-04-25 | 18 Nisan 5787 (Chol HaMoed Pesach) | All | Ya'aleh v'yavo; No Tachanun; Omit Lamnatzeach; Omit Mizmor l'Todah |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Half Hallel; Sefirat haOmer tonight: 4 days baOmer |
| | | Sefard | Morid haTal; V'ten beracha; Half Hallel; Sefirat haOmer tonight: 4 days laOmer |
| | | Chabad | Morid haTal; V'ten beracha; Half Hallel; Sefirat haOmer tonight: 4 days laOmer |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Half Hallel (no beracha); Sefirat haOmer tonight: 4 days laOmer |
| Tue 2027-05-25 | 18 Iyar 5787 (Lag BaOmer) | All | No Tachanun |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Sefirat haOmer tonight: 34 days — 4 weeks and 6 days — baOmer |
| | | Sefard | Morid haTal; V'ten beracha; Sefirat haOmer tonight: 34 days — 4 weeks and 6 days — laOmer |
| | | Chabad | Morid haTal; V'ten beracha; Sefirat haOmer tonight: 34 days — 4 weeks and 6 days — laOmer |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Sefirat haOmer tonight: 34 days — 4 weeks and 6 days — laOmer |
| Fri 2027-06-18 | 13 Sivan 5787 (Last Edot HaMizrach day) | All | Kiddush Levanah until Sat 19 Jun, 09:36 |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Tachanun at Shacharit only (none at Mincha) |
| | | Sefard | Morid haTal; V'ten beracha; Tachanun at Shacharit only (none at Mincha) |
| | | Chabad | Morid haTal; V'ten beracha; Tachanun at Shacharit only (none at Mincha) |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); No Tachanun |
| Thu 2027-07-22 | 17 Tammuz 5787 (Shiva Asar b'Tammuz) | All | Tachanun |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Aneinu (Shiva Asar b'Tammuz) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Sefard | Morid haTal; V'ten beracha; Aneinu (Shiva Asar b'Tammuz) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Chabad | Morid haTal; V'ten beracha; Aneinu (Shiva Asar b'Tammuz) at Mincha, chazan also at Shacharit; Avinu Malkeinu |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Aneinu (Shiva Asar b'Tammuz) at Shacharit and Mincha |
| Tue 2027-08-10 | 7 Av 5787 (Before Tisha b'Av) | All | Tachanun; Kiddush Levanah after Tisha b'Av |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha |
| | | Sefard | Morid haTal; V'ten beracha |
| | | Chabad | Morid haTal; V'ten beracha |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer) |
| Thu 2027-08-12 | 9 Av 5787 (Tisha b'Av) | All | Nachem at Mincha; No Tachanun; Omit Lamnatzeach; Kiddush Levanah after Tisha b'Av |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Aneinu (Tisha b'Av) at Mincha, chazan also at Shacharit |
| | | Sefard | Morid haTal; V'ten beracha; Aneinu (Tisha b'Av) at Mincha, chazan also at Shacharit |
| | | Chabad | Morid haTal; V'ten beracha; Aneinu (Tisha b'Av) at Mincha, chazan also at Shacharit |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Aneinu (Tisha b'Av) at Shacharit and Mincha |
| Fri 2027-08-13 | 10 Av 5787 (After Tisha b'Av) | All | Tachanun at Shacharit only (none at Mincha); Kiddush Levanah until Tue 17 Aug, 11:05 |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha |
| | | Sefard | Morid haTal; V'ten beracha |
| | | Chabad | Morid haTal; V'ten beracha |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer) |
| Mon 2027-09-20 | 18 Elul 5787 (18 Elul) | Ashkenaz | Summer: no morid haTal; V'ten beracha; Tachanun; L'David Hashem Ori |
| | | Sefard | Morid haTal; V'ten beracha; Tachanun; L'David Hashem Ori |
| | | Chabad | Morid haTal; V'ten beracha; No Tachanun; L'David Hashem Ori |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Tachanun; L'David Hashem Ori (many say it all year) |
| Mon 2027-10-04 | 3 Tishrei 5788 (Tzom Gedaliah) | All | Aseret Yemei Teshuvah: haMelech haKadosh, haMelech haMishpat, Zochreinu, Mi Chamocha, U'chtov, B'sefer Chayim, Oseh haShalom; Avinu Malkeinu; Tachanun |
| | | Ashkenaz | Summer: no morid haTal; V'ten beracha; Aneinu (Tzom Gedaliah) at Mincha, chazan also at Shacharit; L'David Hashem Ori; Kiddush Levanah after Yom Kippur |
| | | Sefard | Morid haTal; V'ten beracha; Aneinu (Tzom Gedaliah) at Mincha, chazan also at Shacharit; L'David Hashem Ori |
| | | Chabad | Morid haTal; V'ten beracha; Aneinu (Tzom Gedaliah) at Mincha, chazan also at Shacharit; L'David Hashem Ori |
| | | Edot HaMizrach | Morid haTal; Barchenu (summer); Aneinu (Tzom Gedaliah) at Shacharit and Mincha; L'David Hashem Ori (many say it all year) |
