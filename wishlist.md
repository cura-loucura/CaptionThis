Improvements

- Remove Delay functionality. It is redundant with the history display

- CaptureThis, allow user to enter how many minutes it should record after starting. (eg. 23 Minutes, 25 Minutes)

- Caption files should not use current Timestamp but instead start with 0 and the timedelta as time from the start of the recording. This will break when the user makes multiple captures in the same file but it is acceptable for now and is registered on the known_issues for future fixes.

- In the future, when the translation and transcript are working properly without duplicated sentences, a proper srt file should be generated. 