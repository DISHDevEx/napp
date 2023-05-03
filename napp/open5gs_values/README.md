## RESPONS-NUANCES - RESPONS NAPP with User plane, Access Network, Control plane, and Equipment Separation

### Background

Following the CUPS notation of 5G, we wanted to have logical separation of control
plane and user plane. In order to achieve that, we created a new cluster with multiple
nodegrouops. Further, to suit our business use case, we also separated UEs and gNB from
the user plane to have 4 major nodegroups:
- ues
- gnb
- upf
- control_plane
