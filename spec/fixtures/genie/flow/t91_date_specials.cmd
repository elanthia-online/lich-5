# WP5 (G63): .NET custom formats of the @-specials (Globals.cs:224-236 R): M/d/yyyy is
# unpadded, HH:mm:ss tt is 24-hour WITH a designator, DayOfYear is unpadded, mm is minutes.
echo t=[@time@] t24=[@time24@] d=[@date@] dt=[@datetime@] dt24=[@datetime24@]
echo mt=[@militarytime@] y=[@year@] mo=[@month@] dom=[@dayofmonth@] doy=[@dayofyear@] u=[@unixtime@]
echo r=[$time] [$time24] [$date] [$dayofyear] [$month] [$datetime24]
