action put react $1 when ^Then (\w+) happens
put look
match go First line
matchwait
go:
put after-match
