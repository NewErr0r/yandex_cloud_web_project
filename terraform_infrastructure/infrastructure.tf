data "yandex_compute_image" "debian_image" {
  family = "debian-11"
}

# Создаём VM 'app'
resource "yandex_compute_instance" "app" {        
    name        = "app"  
    zone        = "ru-central1-a"

    resources {
        cores   = 2                                            
        memory  = 2                                           
    }

    boot_disk {
        initialize_params {
            image_id = data.yandex_compute_image.debian_image.id
            size     = 15 #GB
        }
    }

    network_interface {
        subnet_id   = yandex_vpc_subnet.subnet-1.id
        ip_address  = "192.168.15.101"
        nat         = true
    }

    scheduling_policy {
      preemptible = true                       # Прерываемая VM            
    }

    metadata = {
        ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"     # debian - логин пользователя
    }
}

# Создаём VM app_gw
resource "yandex_compute_instance" "app_gw" {
    name        = "app-gw"  
    zone        = "ru-central1-a"

    resources {
        cores   = 2                                            
        memory  = 2                                           
    }

    boot_disk {
        initialize_params {
            image_id = data.yandex_compute_image.debian_image.id
            size     = 15 #GB
        }
    }

    network_interface {
        subnet_id   = yandex_vpc_subnet.subnet-1.id
        ip_address  = "192.168.15.100"
        nat         = true
    }

    scheduling_policy {
      preemptible = true                         # Прерываемая VM 
    }

    metadata = {
        ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"     # debian - логин пользователя
    }
}

# Создаём сеть
resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

# Создаём подсеть
resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.15.0/24"]
}

# Создание динамического inventory для Ansible для подключения к APP_GW
data "template_file" "inventory" {
    template = file("./_templates/inventory.tpl")
  
    vars = {
        user = "debian"
        host-1 = join("", [yandex_compute_instance.app_gw.name, " ansible_host=", yandex_compute_instance.app_gw.network_interface.0.nat_ip_address])
        host-2 = join("", [yandex_compute_instance.app.name, " ansible_host=", yandex_compute_instance.app.network_interface.0.nat_ip_address])
    }
}

resource "local_file" "save_inventory" {
   content  = data.template_file.inventory.rendered
   filename = "./inventory"
}